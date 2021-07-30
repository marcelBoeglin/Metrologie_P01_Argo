/**
 * 20210726_Metrologie_P01_Zeiss_Observer.ijm
 * 
 * Necessite l'ouverture de 2 images CZI (.czi) :
 * 
1. P01 : Image du motif de 4x4 carrés de la lame Argolight (Fluorescent Calibration
   Slide, Argo-M).
   Le carré le plus brillant doit être en haut de l'image.
   Nomenclature :
   JJ_MM_AAAA-P01_Ojectif(20x ou 40x)NA_ArgoM_Lambda_TempsExpo_Illumination.czi
   exemple :
   02_06_2021-P01_20X0.8_ArgoM_500_60.czi // il manque l'illumination

2. P02 : Image de correction de l'illumination (lame Chroma verte) :
   Nomenclature :
   JJ_MM_AAAA-P02_Ojectif(20x ou 40x)NA_ArgoM_Lambda_TempsExpo_Illumination.czi
   exemple :
   02_06_2021-P02_20X0.8_475_13_1.5.czi

Les résultats sont enregistrés automatiquement dans un sous-dossier du dossier contenant l'image
Argolight.

 * Marcel Boeglin July 2021
 * boeglin@igbmc.fr
 */

var version = "20210729";
var macroname = version+"_Metrologie_P01_Zeiss_Observer.ijm"
var saveLog = true;
var closeAll = false;

var microscope = "Zeiss Observer";
var objective = "20x";

var inputDir;
var argolightPath;
var argolightImageName;
var argoLightID;

var flatFieldPath;
var flatFieldImageName;
var flatFieldID;
var flatFieldName;

var doDarkCurrentSubtraction;
var darkCurrent = 400;

/* tjs true */
var doFlatFieldCorrection = true;

var inputFileName;//a remplacer par argolightImageName+extension
var extension;
var unit, pixelWidth, pixelHeight;
var flatFieldMean = 1;
var outpuDir;
var outputPath;
var outputName;

var width, height;
var unit;
var pixelWidth, pixelHeight;

/* Côté des carrés du réseau 4x4 de la lame Argolight en micron */
var dotsWidth = 52.35;//microns, measured on image from Zeiss-Observer, obj. 20x0.8
var dotsArea = dotsWidth*dotsWidth;//micron square

/* coté du carré formé par les centres des 4 carrés des coins du motif en microns */
var dotsArrayWidth = 179.2;//microns, measured on image from Zeiss-Observer, obj. 20x0.8

/* dotsArrayParameter : pas du réseau de 4x4 carrés de la lame Argolight-M (59.55 microns) */
var dotsArrayParameter = dotsArrayWidth / 3; // 59.55 microns

//computation of Rois-grid
var nDots = 16;
var dotCentersX = newArray(nDots);

var dotsGap = dotsArrayParameter - dotsWidth;//microns
var dotsGapPixels;// = dotsGap/pixelWidth;//pixels

var gridCols = 4;
var gridRows = 4;
var gridCenterX, gridCenterY;
var gridWidth = dotsArrayWidth;
var gridHeight = dotsArrayWidth;
var roisWidth = dotsWidth * 0.85;//physical units, for grid computation

var sampleTilt;

var xStep = dotsArrayWidth / gridCols;
var yStep = dotsArrayWidth / gridRows;
var TopLeft = newArray(2);
var TopRight = newArray(2);
var BottomRight = newArray(2);
var BottomLeft = newArray(2);

var brightestSquarePosition = "TopRight";//ou TopLeft
var scanDirection;//RightToLeft ou LeftToRight
/* La lame Argolight doit être orientée de manière à ce que le carré le plus intense soit en haut */

run("Close All");
print("\\Clear");
//run("Bio-Formats Macro Extensions");
print(macroname+"\n ");

getParams();
getArgolightPath();
open(argolightPath);
rename("Argolight");
argoLightID = getImageID();

width = getWidth();
height = getHeight();
getPixelSize(unit, pixelWidth, pixelHeight);
//print("inputFileName = "+inputFileName);
//print("argolightImageName = "+argolightImageName);

if (doDarkCurrentSubtraction) {
	choice = "";
	Dialog.create("Dark current");
	items = newArray("= argolight image background", "= value below");
	Dialog.addChoice("Dark current", items, "= Argolight image background");
	Dialog.addNumber("", darkCurrent, 0, 6, "");
	Dialog.show();
	choice = Dialog.getChoice();
	darkCurrent = Dialog.getNumber();
	if (choice=="= Argolight image background") {
		selectImage(argoLightID);
		waitForUser("Draw an Roi for dark-current measurement");
		getStatistics(area, mean, min, max, std, histogram);
		darkCurrent = mean;
		Roi.remove;
	}
//	print("darkCurrent = "+darkCurrent);
}

if (doFlatFieldCorrection) {
	getFlatFieldPath();
	//print("flatFieldImageName : "+flatFieldImageName);
	open(flatFieldPath);	
	//Inutile si flatfield est intense (~ 40 000, darkCurrent ~ 1000)
	//if (darkCurrent>0) run("Subtract...", "value="+darkCurrent);
	flatFielID = getImageID();
}

print("inputDir :");
print(inputDir);
print("inputFileName = "+inputFileName);
print("argolightImageName = "+inputFileName);
print("extension = "+extension);
inputFile = inputFileName + extension;
print("inputFile = "+inputFile);

outputName = argolightImageName+extension;
print("outputName = "+outputName+"\n ");


outputDir = inputDir + inputFile;
outputDir += "_Mesures";
outputDir += File.separator;
print("outputDir:");
print(outputDir);
if (!File.exists(outputDir)) {
	print("\nCreating output directory\n ");
	File.makeDirectory(outputDir);
}

//File.makeDirectory(outputDir);

roisWidth = dotsWidth * 0.85;//physical units, for grid computation
dotsGap = dotsArrayParameter - dotsWidth;//microns


//IMAGE ACTIVE : flatFieldID

/*
width = getWidth();
height = getHeight();
getPixelSize(unit, pixelWidth, pixelHeight);
//print("inputFileName = "+inputFileName);
print("argolightImageName = "+argolightImageName);
*/

resetMinAndMax();
rename("Argolight");
getPixelSize(unit, pixelWidth, pixelHeight);

flatfieldoutputName = flatFieldImageName;

rename("Flatfield");
run("Gaussian Blur...", "sigma=2");
getStatistics(area, flatFieldMean, min, flatFieldMax, std, histogram);
print("");
//print("flatFieldMean = "+flatFieldMean);
flatFieldID = getImageID();
print("");


//Create corrected ArgoLight image for intensity measurements
selectImage(argoLightID);
//ATTENTION : l'option choisie ci dessous suppose que le courant d'obscurite est faible
print("Correcting Argolight image:");
print("flatfield image: "+flatFieldImageName);
print("flatFieldMean = "+flatFieldMean);
print("Background correction = darkCurrent = "+darkCurrent);
/*
//A utiliser si l'image Argolight est faible par rapport a darkCurrent (~= 600)
if (darkCurrent>0) run("Subtract...", "value="+darkCurrent);
run("Calculator Plus",
	"i1=Argolight i2=Flatfield operation=[Divide: i2 = (i1/i2) x k1 + k2] k1="+
	flatFieldMean+" k2=0 create");
*/
//A utiliser si l'image Argolight est intense par rapport a darkCurrent (~ 600)
run("Calculator Plus",
	"i1=Argolight i2=Flatfield operation=[Divide: i2 = (i1/i2) x k1 + k2] k1="+
	flatFieldMean+" k2="+(-darkCurrent)+" create");

setVoxelSize(pixelWidth, pixelHeight, 0, unit);
rename("CorrectedArgoLight");
correctedArgoLightID = getImageID();


//Create processed Argolight image for squares detection
print("\nSTART of squares-motif detection, Rois-grid creation and adjustment on motif");
run("Duplicate...", " ");
rename("ProcessedArgoLight");
processedArgoLightID = getImageID();
outliersRadiusPixels = 1.29 / pixelWidth;
if (outliersRadiusPixels<4) outliersRadiusPixels = 4;
print("outliersRadiusPixels = "+outliersRadiusPixels);
run("Remove Outliers...", "radius="+outliersRadiusPixels+" threshold=0 which=Bright");
run("Remove Outliers...", "radius="+outliersRadiusPixels+" threshold=0 which=Dark");
dotsGapPixels = dotsGap/pixelWidth;
print("dotsGap = "+dotsGap);
print("pixelWidth = "+pixelWidth);
print("dotsGapPixels = "+dotsGapPixels);
rollingPixels = dotsWidth/pixelWidth/2;
print("rollingPixels = "+rollingPixels);
run("Subtract Background...", "rolling="+(rollingPixels/2)+" sliding disable");
run("Gamma...", "value=0.50");
/*
outliersRadiusPixels = 1.29 / pixelWidth / 2;
print("outliersRadiusPixels = "+outliersRadiusPixels);
run("Remove Outliers...", "radius="+outliersRadiusPixels+" threshold=0 which=Bright");
run("Remove Outliers...", "radius="+outliersRadiusPixels+" threshold=0 which=Dark");
*/
//exit;

getDotsAsRois(processedArgoLightID);

//Create Rois grid and adjust it on processedArgoLight image
getDotsArrayCornersFromRoiManager();
sampleTilt = computeSampleTilt(processedArgoLightID);
getGridCenterFromDotsArrayCorners();
createRoisGrid(processedArgoLightID);
aroundImageCenter = true;
rotateRois(sampleTilt, aroundImageCenter);
translation = computeXYShift(processedArgoLightID);
tx = translation[0];
ty = translation[1];
translateRois(tx, ty);//Translate Roi-grid to fit dot positions
suffix = "_measuredImage";
print("END of squares-motif detection, Rois-grid creation and adjustment on motif\n ");

run("Set Measurements...", "area mean median redirect=None decimal=3");
run("Clear Results");

print("\nMeasuring correctedArgoLight");
selectImage(correctedArgoLightID);
Roi.remove;
roiManager("deselect");
for (i=0; i<roiManager("count"); i++) {
	updateResults();
	roiManager("select", i);
	roiname = Roi.getName;
	run("Measure");
}
for (i=0; i<nResults; i++) {
	roiManager("select", i);
	setResult("Roi", i, i+1);
	updateResults();
}
//print("outputDir:\n"+outputDir);
//print("outputName:\n"+outputName);
saveAs("Results", outputDir+outputName+"_Corrected_Results.txt");

//Add measurement squares to corrected Argolight image
roiManager("Show None");
nRois = roiManager("count");
for (i=0; i<nRois; i++) {
	roiManager("select", i);
	Overlay.addSelection;
	Roi.getBounds(x, y, width, height);
	size = dotsWidth / (pixelWidth*2);
	options = "bold scale";
	Overlay.setLabelFontSize(size, options);
	Overlay.drawLabels(true);
}
Roi.remove;
//run("Fire");
//save corrected Argolight image
resetMinAndMax();
saveAs("Tiff", outputDir+outputName+"_Corrected.tif");

selectImage(flatFieldID);
for (i=0; i<nRois; i++) {
	roiManager("select", i);
	Overlay.addSelection;
	Roi.getBounds(x, y, width, height);
	size = dotsWidth / (pixelWidth*2);
	options = "bold scale";
	Overlay.setLabelFontSize(size, options);
	Overlay.drawLabels(true);
}
	Roi.remove;
	run("Fire");
	saveAs("Tiff", outputDir+flatfieldoutputName+".tif");

if (isOpen(processedArgoLightID)) {
	selectImage(processedArgoLightID);
	//close();
}
selectWindow("Results");
Plot.create("Plot of Results", "Roi", "Median");
Plot.add("Circle",
	Table.getColumn("Roi", "Results"), Table.getColumn("Median", "Results"));
Plot.setStyle(0, "blue,#a0a0ff,4.0,Circle");
Plot.addLegend(outputName+"_Corrected", "Bottom-Left");
Plot.show();
saveAs("PNG", outputDir+outputName+"_Corrected_Results_Median.png");

//Measure uncorrected Argolight image
selectImage(argoLightID);
run("Set Measurements...", "area mean median redirect=None decimal=3");
run("Clear Results");
print("Measuring argoLight");
Roi.remove;
roiManager("deselect");
for (i=0; i<roiManager("count"); i++) {
	updateResults();
	roiManager("select", i);
	roiname = Roi.getName;
	run("Measure");
}

for (i=0; i<nResults; i++) {
	roiManager("select", i);
	setResult("Roi", i, i+1);
	updateResults();
}
saveAs("Results", outputDir+outputName+"_Uncorrected_Results.txt");
//Add measurement squares to uncorrected Argolight image
roiManager("Show None");
nRois = roiManager("count");
for (i=0; i<nRois; i++) {
	roiManager("select", i);
	Overlay.addSelection;
	Roi.getBounds(x, y, width, height);
	size = 60;
	size = dotsWidth / (pixelWidth*2);
	options = "bold scale";
	Overlay.setLabelFontSize(size, options);
	Overlay.drawLabels(true);
}
Roi.remove;
//save uncorrected Argolight image
resetMinAndMax();
saveAs("Tiff", outputDir+outputName+"_Uncorrected.tif");
selectWindow("Results");
Plot.create("Plot of Results", "Roi", "Median");
Plot.add("Circle",
	Table.getColumn("Roi", "Results"), Table.getColumn("Median", "Results"));
Plot.setStyle(0, "blue,#a0a0ff,4.0,Circle");
Plot.addLegend(outputName+"_Uncorrected", "Bottom-Left");
Plot.show();
saveAs("PNG", outputDir+outputName+"_Uncorrected_Results_Median.png");
if (closeAll) run("Close All");

printVariables();

print("\nEnd "+macroname);

if (isOpen("Log")) {
	selectWindow("Log");
	if (saveLog) saveAs("Text", outputDir+outputName+"_Log.txt");
}
//END MACRO

function printVariables() {
	print("\nVariables:");
	print("inputDir:");
	print(inputDir);
	print("inputFileName : "+inputFileName);
	print("extension : "+extension);
	print("argolightImageName : "+argolightImageName);
	print("flatFieldImageName : "+flatFieldImageName);
	print("outputDir:");
	print(outputDir);
	print("outputName : "+outputName);
	print("doDarkCurrentSubtraction : "+doDarkCurrentSubtraction);
	print("darkCurrent = "+darkCurrent);
	print("doFlatFieldCorrection : "+doFlatFieldCorrection);
	print("flatFieldMean : "+flatFieldMean);
	print("");
	print("pixelWidth : "+pixelWidth);
	print("pixelHeight : "+pixelHeight);
	print("unit : "+unit);
	print("");
	print("microscope : "+microscope);
	print("objective : "+objective);
	print("brightestSquarePosition : "+brightestSquarePosition);
	print("scanDirection : "+scanDirection);
	print("");
	print("dotsArrayParameter = "+dotsArrayParameter);
	print("gridWidth : "+gridWidth);
	print("gridHeight : "+gridHeight);
	print("roisWidth = "+roisWidth);
	print("dotsArea = "+dotsArea);
	print("dotsWidth = "+dotsWidth);
	print("dotsGap = "+dotsGap);
	print("\ncloseAll = "+closeAll);
}

function getParams() {
	Dialog.create("Params for "+microscope);
	brightestSquarePositions = newArray("TopLeft", "TopRight");
	Dialog.addChoice("Brightest Square Position", brightestSquarePositions, brightestSquarePosition);
	objectives = newArray("10x", "20x", "40x");
	Dialog.addChoice("Objective", objectives, objective);
//	Dialog.addCheckbox("Do flat-field correction", doFlatFieldCorrection);
	Dialog.addCheckbox("Subtract dark current", doDarkCurrentSubtraction);
	Dialog.addCheckbox("Save LOG", saveLog);
	Dialog.addCheckbox("Close all after run", closeAll);
	Dialog.show();
	brightestSquarePosition = Dialog.getChoice();
	if (brightestSquarePosition=="TopLeft") scanDirection = "LeftToRight";
	else scanDirection = "RightToLeft";
	objective = Dialog.getChoice();
	//doFlatFieldCorrection = Dialog.getCheckbox();
	doDarkCurrentSubtraction = Dialog.getCheckbox();
	saveLog = Dialog.getCheckbox();
	closeAll = Dialog.getCheckbox();
}

function getArgolightPath()  {
	argolightPath = File.openDialog("Select Argolight image");
	inputDir = File.getDirectory(argolightPath);
	argolightImageName = File.getNameWithoutExtension(argolightPath);
	inputFileName = argolightImageName;
	extension = substring(argolightPath, lastIndexOf(argolightPath, "."));
//	open(inputDir+argolightImageName);
	//open(argolightPath);
}

function getFlatFieldPath()  {
	flatFieldPath = File.openDialog("Select flatfield image");
	flatFieldImageName = File.getNameWithoutExtension(flatFieldPath);
}

/** Processes, segments and analyzes active channel of image 'id'
	and stores the dots as Rois in RoiManager.
	This is the critical part of the procedure. May fail if dots are irregular
	or have unequal intensities. */
function getDotsAsRois(id) {
	print("getDotsAsRois(id):");
	selectImage(id);
	Roi.remove;
	run("Remove Overlay");
	setOption("BlackBackground", true);
	resetMinAndMax;
	setAutoThreshold("Triangle dark");
	setAutoThreshold("Li dark");
	roiManager("reset");
	run("Set Measurements...", "centroid display redirect=None decimal=3");
	tolerance = 20;// %
	tolerance = 25;// %
	//tolerance = 15;// < 15 => problemes de detection

	if (isOpen("ROI Manager")) roiManager("reset");
	minArea = dotsArea*(100-tolerance)/100;
	maxArea = dotsArea*(100+tolerance)/100;
	print("minArea = "+minArea);
	print("maxArea = "+maxArea);
	print("objective = "+objective);

	run("Threshold...");
	//setAutoThreshold("Huang dark");
	setAutoThreshold("Li dark");
	//setAutoThreshold("Yen dark");
	//setAutoThreshold("Mean dark");
	//setAutoThreshold("Triangle dark");
	//setAutoThreshold("RenyiEntropy dark");
	setTool("rectangle");
	//waitForUser("Draw a rectangle around the array of fluorescent squares");
	waitForUser("You can draw a Roi, \nchange the threshold or"+
		"\nedit image with pencil to separate or close squares");

	print("minDotArea = "+minArea+"   maxDotArea = "+maxArea);
	run("Analyze Particles...",
		"size="+minArea+"-"+maxArea+" exclude display clear include add");
	detectedDots = roiManager("count");
	print("Detected "+detectedDots+" dots");
	resetThreshold;
	n=gridRows*gridCols;
	if (detectedDots != gridRows*gridCols) {
		print("An error occured in dots detection: should find "+n+"dots");
		close();
		print("End getDotsAsRois(id):");
		return 0;
	}
	print("End getDotsAsRois(id):");
	return getImageID();
}

function getGridCenterFromDotsArrayCorners() {
	print("getGridCenterFromDotsArrayCorners()");
	if (roiManager("count")!=nDots) {
		print("dotsDetectionFailed");
		print("End getGridCenterFromDotsArrayCorners()");
		return;
	}
	//corners coordinates are in physical units
	gridCenterX = (TopLeft[0]+TopRight[0]+BottomRight[0]+BottomLeft[0])/4;
	gridCenterY = (TopLeft[1]+TopRight[1]+BottomRight[1]+BottomLeft[1])/4;
	print("gridCenterX = "+gridCenterX+" "+unit);
	print("gridCenterY= "+gridCenterY+" "+unit);
	print("End getGridCenterFromDotsArrayCorners()");
}

/* Creates a grid of Rois */
function createRoisGrid(imageID) {
//function createCircularRoisGridForResolution3(imageID) {
	print("createCircularRoisGridForResolution3(imageID)");
	print("gridCols = "+gridCols);
	print("gridRows = "+gridRows);
	xStep = gridWidth/(gridCols-1);
	yStep = gridHeight/(gridRows-1);
	print("xStep = "+xStep);
	print("yStep = "+yStep);
	print("scanDirection = "+scanDirection);
	print("roisWidth = "+roisWidth+" "+unit);
	getGridCenterFromDotsArrayCorners();
	print("gridWidth = "+gridWidth);
	print("gridHeight = "+gridHeight);
	physicalUnits = true;

	createRoiGrid(gridCenterX, gridCenterY,
		gridCols, gridRows, xStep, yStep,
		scanDirection, roisWidth, physicalUnits);
	print("End createRoiGrid(imageID)");
}

/*	Creates an grid of rois and stores them in the roiManager;
	centerX, centerY: coordinates of grid-center
	xStep, yStep: x and y periods
	scanSirection: "RightToLeft" or "LeftToRight"
	roisWidth: size  of the rois
	If !physicalUnits, lengths and positions must be passed in pixels */
function createRoiGrid(centerX, centerY, cols, rows,
		xStep, yStep, scanDirection, roisWidth, physicalUnits) {
	roiManager("reset");
	//cx, cy, xs, ys: center coordinates and steps in pixels
	cx = centerX; cy = centerY;
	xs = xStep; ys = yStep;
	roisWidthPixels = roisWidth / pixelWidth;

	//convert lengths and positions to pixels
	cx /= pixelWidth; cy /= pixelHeight;
	xs /= pixelWidth; ys /= pixelHeight;
	print("roisWidthPixels = "+roisWidthPixels);
	
	str = ""+cols*rows;
	digits = str.length;
	i=0;
	//roiCenterX, roiCenterY in pixels
	for (r=0; r<rows; r++) {
		roiCenterY = cy - ys*(rows-1)/2 + r*ys;
		if (scanDirection=="RightToLeft") {
			for (c=cols-1; c>=0; c--) {
				roiCenterX = cx - xs*(cols-1)/2 + c*xs;
				makeRectangle(roiCenterX-roisWidthPixels,
					roiCenterY-roisWidthPixels,
					1*roisWidthPixels, 1*roisWidthPixels);
				setSelectionName(String.pad(++i, digits));
				roiManager("add");
			}
		}
		else if (scanDirection=="LeftToRight") {
			for (c=0; c<cols; c++) {
				roiCenterX = cx - xs*(cols-1)/2 + c*xs;
				makeRectangle(roiCenterX-roisWidthPixels,
					roiCenterY-roisWidthPixels,
					1*roisWidthPixels, 1*roisWidthPixels);
				setSelectionName(String.pad(++i, digits));
				roiManager("add");
			}
		}
	}
	roiManager("deselect");
	Roi.remove;
	print("End createRoiGrid()");
}

/* Computes corners coordinates in physical units (microns) */
function getDotsArrayCornersFromRoiManager() {
	print("getDotsArrayCornersFromRoiManager()");
	xmin = width*pixelWidth; ymin = height*pixelHeight;//TopLeft dot
	xmax = 0; ymax = 0;//BottomRight dot
	run("From ROI Manager");
	nRois = getValue("results.count");
	print("nRois = "+nRois);
	print("nDots = "+nDots);
	if (nRois!=nDots) {
		exit(""+nRois+" Rois detectees au lieu de 16");
	}
	for (i=0; i<nDots; i++) {
		x = getResult("X", i);
		y = getResult("Y", i);
		if (x+y < xmin+ymin) {
			xmin=x; ymin=y;
		}
		if (x+y > xmax+ymax) {
			xmax=x; ymax=y;
		}
	}
	TopLeft[0]=xmin; TopLeft[1]=ymin;
	BottomRight[0]=xmax; BottomRight[1]=ymax;
	print("TopLeft[0]="+xmin+"  TopLeft[1]="+ymin+
		"  BottomRight[0]="+xmax+"  BottomRight[1]="+ymax);
	xmax=0; ymin=height*pixelHeight;//TopRight dot
	xmin=width*pixelWidth; ymax=0;//BottomLeft dot
	nDots = getValue("results.count");
	for (i=0; i<nDots; i++) {
		x = getResult("X", i);
		y = getResult("Y", i);
		if (x-y < xmin-ymax) {
			xmin=x; ymax=y;
		}
		if (x-y > xmax-ymin) {
			xmax=x; ymin=y;
		}
	}
	TopRight[0]=xmax; TopRight[1]=ymin;
	BottomLeft[0]=xmin; BottomLeft[1]=ymax;
	print("BottomLeft[0]="+xmin+"  TopRight[1]="+ymin+
			"  TopRight[0]="+xmax+"  BottomLeft[1]="+ymax);
	print("End getDotsArrayCornersFromRoiManager()");
}

/** Computes the angle by which rotate the Roi-grid to fit the dots array
	in image to be analyzed 
	For that, detects centers of TopLeft, BottomRight, TopRight and BottomLeft dots*/
function computeSampleTilt(imgID) {
	print("computeSampleTilt(imgID)");
	diagonalAngle = 45;
	if (gridRows!=gridCols)
		diagonalAngle = Math.atan(gridRows/gridCols);//to be verified
	print("BEFORE getDotsArrayCornersFromRoiManager()");
	getDotsArrayCornersFromRoiManager();
	print("After getDotsArrayCornersFromRoiManager()");
	fitSquare = true;
	run("Remove Overlay");
	print("TopLeftX="+TopLeft[0]+"  TopLeftY="+TopLeft[1]);
	print("BottomRightX="+BottomRight[0]+"  BottomRightY="+BottomRight[1]);
	pw = pixelWidth;
	x1=BottomRight[0]/pw; x2=TopLeft[0]/pw; x3=width;
	y1=BottomRight[1]/pw; y2=TopLeft[1]/pw; y3=TopLeft[1]/pw;
	makeSelection("angle",newArray(x1,x2,x3),newArray(y1,y2,y3));
wait(1000);
	run("Clear Results");
	run("Measure");
	tilt1 = getResult("Angle", 0) - diagonalAngle;
	print("tilt1="+tilt1);

	//2nd measurement of tilt, to be averaged with 1st:
	print("TopRightX="+TopRight[0]+"  TopRightY="+TopRight[1]);
	print("BottomLeftX="+BottomLeft[0]+" BottomLeftY="+BottomLeft[1]);
	x1=width; x2=BottomLeft[0]/pw; x3=TopRight[0]/pw;
	y1=BottomLeft[1]/pw; y2=BottomLeft[1]/pw; y3=TopRight[1]/pw;
	makeSelection("angle",newArray(x1,x2,x3),newArray(y1,y2,y3));
wait(1000);
	run("Clear Results");
	run("Measure");
	tilt2 = diagonalAngle - getResult("Angle", 0);
	print("tilt2="+tilt2);
	print("End computeSampleTilt(imgID)");
	tilt = (tilt1+tilt2)/2;
	print("tilt = "+tilt);
	print("End computeSampleTilt(imgID)");
	return tilt;
}

/**
 * Rotates all rois in roiManager by 'angle' degrees:
 * around image center if aroundImageCenter is true;
 * aroud roi center otherwise.
	//test-code:
		aroundImageCenter = true;
		angle = 12; //degrees
		rotateRois(12, aroundImageCenter);
 */
function rotateRois(angle, aroundImageCenter) {
	nrois = roiManager("count");
	param = "";
	if (aroundImageCenter) param = "rotate ";
	for (i=0; i<nrois; i++) {
		roiManager("select", i);
		run("Rotate...", param+" angle="+angle);
		roiManager("update");
	}
	roiManager("deselect");
	Roi.remove;
}

/** Translates all rois in roiManager by 'tx', 'ty'
	//test-code:
		tx=10; ty=20;
		translateRois(tx, ty);
*/
function translateRois(tx, ty) {
	nrois = roiManager("count");
	for (i=0; i<nrois; i++) {
		roiManager("select", i);
		getSelectionBounds(x, y, w, h);
		Roi.move(x+tx, y+ty);
		roiManager("update");
	}
	roiManager("deselect");
	Roi.remove;
}

/** Returns the translation to be applied to the Roi-grid after it has been
	rotated around the image center to fit the dots in brightfield image.
	Uses the four corners of the grid for better precision
	Components of translation are expressed in pixels */
function computeXYShift(imageID) {
	print("computeXYShift()");
	selectImage(imageID);
	getPixelSize(unit, pixWidth, pixHeight);
	if (nDots!=gridRows*gridCols) {
		print("An error occured in dots detection");
		print("tx="+0+"  ty="+0);
		print("End computeXYShift()");
		return newArray(0,0);
	}
	roiManager("select", 0);//TopLeft
	getSelectionBounds(x0, y0, w0, h0);
	Roi.remove;
	//Corner coordinates are returned in physical units
	//while getSelectionBounds returns values in pixels
	tx0 = TopLeft[0]/pixWidth - (x0+w0/2);
	ty0 = TopLeft[1]/pixHeight - (y0+h0/2);
	print("tx0="+tx0+"\nty0="+ty0);

	rows = sqrt(nDots);
	roiManager("select", rows-1);//TopRight
	getSelectionBounds(x1, y1, w1, h1);
	Roi.remove;
	tx1 = TopRight[0]/pixWidth - (x1+w1/2);
	ty1 = TopRight[1]/pixHeight - (y1+h1/2);
	print("tx1="+tx1+"\nty1="+ty1);

	roiManager("select", nDots-1);//BottomRight
	getSelectionBounds(x2, y2, w2, h2);
	Roi.remove;
	tx2 = BottomRight[0]/pixWidth - (x2+w2/2);
	ty2 = BottomRight[1]/pixHeight - (y2+h2/2);
	print("tx2="+tx2+"\nty2="+ty2);

	roiManager("select", nDots-rows);//BottomLeft
	getSelectionBounds(x3, y3, w3, h3);
	Roi.remove;
	tx3 = BottomLeft[0]/pixWidth - (x3+w3/2);
	ty3 = BottomLeft[1]/pixHeight - (y3+h3/2);
	print("tx3="+tx3+"t\ny3="+ty3);

	//average to increase precision
	tx = (tx0+tx1+tx2+tx3)/4;
	ty = (ty0+ty1+ty2+ty3)/4;
	print("tx="+tx+"\nty="+ty);

	print("End computeXYShift()");
	return newArray(tx,ty));
}
/*
 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789
*/
