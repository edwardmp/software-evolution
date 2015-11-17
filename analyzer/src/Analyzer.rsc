module Analyzer

import Exception;
import List;
import Map;
import IO;
import Set;
import util::Math;
import util::Benchmark;

import CodeDuplicationAnalyzer;
import ASTTraverser;
 
/*
 * A map containing a map with all methods and the the lines in those methods for each class.
 */
private map[str, map[str, list[value]]] linesPerMethod = ();

/*
 * A map containing a map with all methods and the risk category for the size of that method for each class.
 */
private map [str, map[str, int]] unitSizeRiskCategoryPerMethod = ();

/*
 * Indicates whether analysis has been run and lines per method can be obtained.
 */
private bool analysisRan = false;

private int totalVolume = 0;

private loc fileLocation;

/*
 * Set the location to analyze
 */
public void setLocation(loc location) {
	fileLocation = location;
}

public void writeToFile(str content) {
	writeToFile(content, false);
}

public loc writeToFile() {
	return writeToFile("", false);
}

public loc writeToFile(str content, bool isInitialWrite) {
	loc locationWithFileComponent;
	if (isFile(fileLocation))
		locationWithFileComponent = fileLocation.parent + "resultOfAnalysis.txt";
	else
		locationWithFileComponent = fileLocation + "resultOfAnalysis.txt";
	
	str contentWithNewLine = content + "\n";
	
	if(isInitialWrite) {
		if (!isFile(locationWithFileComponent)) {
			writeFile(locationWithFileComponent, contentWithNewLine);
		}
		else {
			// clear contents if file already exists
			writeFile(locationWithFileComponent, contentWithNewLine);
		}
	}
	else {
	 	appendToFile(locationWithFileComponent, contentWithNewLine); 
	}
	
	return locationWithFileComponent;
}

/*
 * Analyze the contents of a location and create output containing the results.
 */
public void main(loc location) {
	analyze(location);
	
	int volumeRank = calculateVolumeRank();
	int duplicationRank = calculateCodeDuplicationRank();
	int unitSizeRank = calculateUnitSizeRank();
	int unitComplexityRank = calculateUnitComplexityRank();
	
	loc analysisFileLoc = writeToFile("--------------------------------------------------------------------------------------------", true);
	writeToFile("AGGREGATE ANALYIS OF JAVA CODE OF CODE IN:\n<location.path>");
	writeToFile("--------------------------------------------------------------------------------------------");
	writeToFile();
	
	printMaintainabilityAspects(volumeRank, duplicationRank, unitSizeRank, unitComplexityRank);
	
	writeToFile("Volume rank: <totalVolume> =\> <numericalScoreToScoreString(volumeRank)>");
	writeToFile("Duplication rank: <getDuplicationVolume()> =\> <numericalScoreToScoreString(duplicationRank)>");
	writeToFile("Unit size rank: <numericalScoreToScoreString(unitSizeRank)>");
	writeToFile("Unit complexity rank: <numericalScoreToScoreString(unitComplexityRank)>");
	writeToFile();
	
	writeToFile("--------------------------------------------------------------------------------------------");
	writeToFile("RESULTS PER METHOD:");
	writeToFile("--------------------------------------------------------------------------------------------");
	writeResultsPerMethod();
	println("Details results were written to file <analysisFileLoc>.");
}

/*
 * Analyze the contents of a location.
 */
public void analyze(loc location) {	
	Analyzer::setLocation(location);
	CodeDuplicationAnalyzer::setLocation(location);
	ASTTraverser::setLocation(location);
	linesOfFilesAtFileLocation();
	linesPerMethod = ASTTraverser::getLinesPerMethod();
	ASTTraverser::setLinesPerMethod(linesPerMethod);
}

/*
 * Write the scores for the different aspects of maintainability to the results file.
 */
public void printMaintainabilityAspects(int volumeRank, int duplicationRank, int unitSizeRank, int unitComplexityRank) {
	list[int] analyzabilityAspects = [volumeRank,duplicationRank,unitSizeRank];
	str analyzability = numericalScoreToScoreString(calculateAverage(analyzabilityAspects));
	println("Analyzability score: <analyzability>");
	
	list[int] changabilityAspects = [unitComplexityRank,duplicationRank];
	str changability = numericalScoreToScoreString(calculateAverage(changabilityAspects));
	println("Changability score: <changability>");
	
	list[int] testabilityAspects = [unitComplexityRank,unitSizeRank];
	str testability = numericalScoreToScoreString(calculateAverage(testabilityAspects));
	println("Testability score: <testability>");
	
	list[int] maintainabilityAspects = [volumeRank,duplicationRank,unitSizeRank,unitComplexityRank];
	str totalMaintainability = numericalScoreToScoreString(calculateAverage(maintainabilityAspects));
	println("Total maintainability score: <totalMaintainability>");
}

/*
 * Write the risk category for the size and complexity of each method to the results file.
 */
public void writeResultsPerMethod() {
	map [str, map[str, int]] unitComplexityRiskCategoryPerMethod = complexityPerMethod();
	
	list[str] classNamesOrderedAlphabetically = sort(domain(unitSizeRiskCategoryPerMethod));
	
	for (cl <- classNamesOrderedAlphabetically) {
		writeToFile(cl);
		list[str] methodNamesOrderedAlphabetically = sort(domain(unitSizeRiskCategoryPerMethod[cl]));
		for (m <- methodNamesOrderedAlphabetically) {
			writeToFile("\t<m>");
			writeToFile("\t\tsize: <unitSizeRiskCategoryPerMethod[cl][m]>");
			writeToFile("\t\tcomplexity: <unitComplexityRiskCategoryPerMethod[cl][m]>");
		}
		writeToFile();
	}
}

/*
 * Calculate the average of a list of integers and round the result to an integer.
 * Calculates the arithmetic average is quite odd if you apply it on ordinal data,
 * but this is what the paper says.
 */
public real calculateAverage(list[int] values) = (sum(values) * 1.0) / size(values);

/*====================================================================================
 * Helper functions for SIG score calculation
 *====================================================================================
 */

/*
 * Converts a score of type int to the same score represented as a string.
 */
private str numericalScoreToScoreString(int score) {
	// pass with real instead of int
	return numericalScoreToScoreString(score * 1.0);
}

/*
 * Converts a score of type real to the same score represented as a string.
 */
private str numericalScoreToScoreString(real score) {
	int roundedScore = round(score);
	
	switch(roundedScore) {
		case -2:
			return "--";
		case -1:
			return "-";
		case 0:
			return "0";
		case 1:
			return "+";
		case 2:
			return "++";
	}
}

/*
 * Check percentages against default SIG thresholds for each risk category.
 */
private int generalSIGRankCalculator(map[int, real] percentageOfLinesInEachCategory) {
	if (percentageOfLinesInEachCategory[3] > 5
	|| percentageOfLinesInEachCategory[2] > 15
	|| percentageOfLinesInEachCategory[1] > 50) {
		return -2;
	}
	else if (percentageOfLinesInEachCategory[3] > 0.5
	|| percentageOfLinesInEachCategory[2] > 10
	|| percentageOfLinesInEachCategory[1] > 40) {
		return -1;
	}
	else if (percentageOfLinesInEachCategory[2] > 5
	|| percentageOfLinesInEachCategory[1] > 30) {
		return 0;
	}
	else if (percentageOfLinesInEachCategory[2] > 0.5
	|| percentageOfLinesInEachCategory[1] > 25) {
		return 1;
	}
	else {
		return 2;
	}
}

/*
 * Returns a map with for each risk category percentages of lines that expose that risk.
 */
private map[int, real] generalCategoryPercentageCalculator(map [str, map[str, int]] riskForEachMethodInClass) {
	map[str, map[str, int]] weights = numberOfLinesPerMethod();
	
	// initialize keys for each category
	map[int, int] numberOfLinesInEachRiskCategory = ();
	numberOfLinesInEachRiskCategory += (1: 0);
	numberOfLinesInEachRiskCategory += (2: 0);
	numberOfLinesInEachRiskCategory += (3: 0);
	
	for (cl <- riskForEachMethodInClass) {
		for (meth <- riskForEachMethodInClass[cl]) {
			int numberOfLinesForMethod = weights[cl][meth];
			int complexityRiskCategory = riskForEachMethodInClass[cl][meth];
			if (complexityRiskCategory != 0) {
				numberOfLinesInEachRiskCategory[complexityRiskCategory] += numberOfLinesForMethod;
			}
		}
	}

	map [int, real] percentageOfLinesInEachCategory = ();
	for (riskCat <- numberOfLinesInEachRiskCategory) {
		int riskCatTotalLines = numberOfLinesInEachRiskCategory[riskCat];
		
		percentageOfLinesInEachCategory[riskCat] = ((riskCatTotalLines * 1.0) / totalVolume) * 100;
	}
	
	return percentageOfLinesInEachCategory;
}

/*====================================================================================
 * Functions that calculate SIG metrics
 *====================================================================================
 */
 
/*
 * Calculate the rank of the volume of all sourcefiles in a location.
 * -2 represents --, -1 represents -, 0 represents 0, 1 represents + and 2 represents ++.
 * This representation was implemented to be able to perform calculations with the rankings.
 */
 public int calculateVolumeRank() {
 	int volume = calculateVolume();
 	if (volume < 66)
 		return 2;
	if (volume < 246)
		return 1;
	if (volume < 665)
		return 0;
	if (volume < 1310)
		return -1;
	return -2;
 }
 
/*
 * Calculate the rank of the unit size of methods in classes in all sourcefiles in a location.
 * -2 represents --, -1 represents -, 0 represents 0, 1 represents + and 2 represents ++.
 * This representation was implemented to be able to perform calculations with the rankings.
 */
 public int calculateUnitSizeRank() {
 	map [str, map[str, int]] numberOfLinesPerMethod = numberOfLinesPerMethod();
 	
	for (cl <- numberOfLinesPerMethod) {
		for (meth <- numberOfLinesPerMethod[cl]) {
			if (cl notin domain(unitSizeRiskCategoryPerMethod)) {
				unitSizeRiskCategoryPerMethod += (cl : ());
			}
			
			int unitSizeForMethod = numberOfLinesPerMethod[cl][meth];
			int unitSizeRiskCategory;
			if (unitSizeForMethod <= 20) {
				unitSizeRiskCategory = 0;
			}
			else if (unitSizeForMethod <= 50) {
				unitSizeRiskCategory = 1;
			}
			else if (unitSizeForMethod <= 100) {
				unitSizeRiskCategory = 2;
			}
			else {
				unitSizeRiskCategory = 3;
			}
			
			unitSizeRiskCategoryPerMethod[cl] += (meth: unitSizeRiskCategory);
		}
	}
	
	return generalSIGRankCalculator(generalCategoryPercentageCalculator(unitSizeRiskCategoryPerMethod));
 }
 
/*
 * Calculate the volume of all sourcefiles in a location.
 * The location must be specified using the file-scheme.
 */
// check if loctolines is ran
public int calculateVolume() {
	throwExceptionWhenAnalysisIsNotRan();
	return totalVolume;
}

/**
 * Calculate the rank of complexity of all units at the analyzed location.
 * -2 represents --, -1 represents -, 0 represents 0, 1 represents + and 2 represents ++.
 * This representation was implemented to be able to perform calculations with the rankings.
 */
public int calculateUnitComplexityRank() {
	map[str, map[str, int]] complexities = complexityPerMethod();
	map [str, map[str, int]] complexitiesRisks = ();
	
	for (cl <- complexities) {
		for (meth <- complexities[cl]) {
			if (cl notin domain(complexitiesRisks)) {
				complexitiesRisks += (cl : ());
			}
			
			int complexityForMethod = complexities[cl][meth];
			int complexityRiskCategory;
			if (complexityForMethod <= 10) {
				complexityRiskCategory = 0;
			}
			else if (complexityForMethod <= 20) {
				complexityRiskCategory = 1;
			}
			else if (complexityForMethod <= 50) {
				complexityRiskCategory = 2;
			}
			else {
				complexityRiskCategory = 3;
			}
			
			complexitiesRisks[cl] += (meth: complexityRiskCategory);
		}
	}
	
	return generalSIGRankCalculator(generalCategoryPercentageCalculator(complexitiesRisks));
}

/*
 * Checks if AST is generated and throws an exception if not.
 */
public void throwExceptionWhenAnalysisIsNotRan() {
	if (!analysisRan) {
		throw AssertionFailed("Analysis not ran. Run linesOfFilesAtFileLocation() first.");
	}
}

/*
 * Get a list of the lines in all sourcefiles in a location, the way they
 * are represented in an AST. We make an estimation of the amount of lines based on
 * general Java code style conventions. E.g. if we find an if statement and a opening curly brace
 * on a new line we count them both as 1 line because this is the style convention.
 * This is in contrast to the getSourceLinesInAllJavaFiles() function which does look at actual source lines
 * regardless of the coding style.
 * The location must be specified using the file-scheme.
 */
public void linesOfFilesAtFileLocation() {
	list[value] lines = astsToLines(locToAsts());
	totalVolume = size(lines);
	analysisRan = true;
}

/*
 * Returns a map from the name of each class, to a map from the name of
 * each method in that class to the lines in that method.
 */
public map[str, map[str, list[value]]] getListOfLinesPerMethod() {
	throwExceptionWhenAnalysisIsNotRan();
	return linesPerMethod;
}

/*
 * Returns a map from the name of each class to a map from name of each method to 
 * the the number of lines for each method.
 */
public map[str, map[str, int]] numberOfLinesPerMethod() {
	throwExceptionWhenAnalysisIsNotRan();

	map[str, map[str, int]] result = ();
	for (cl <- linesPerMethod) {
		// Minus 2 lines for the opening and closing bracket surrounding the method body
		result += (cl : (() | it + (meth : size(linesPerMethod[cl][meth]) - 2) | meth <- linesPerMethod[cl]));	
	}
	
	return result;	
}
