module tester::Tester

import Analyzer;
import IO;
import Exception;

/*
 * Run the analysis on the code in analyzerTestCases and compare it to the results fixture.
 */
public void runTests(bool isEdwardLaptop) {
	loc pathPrefix;
	str resultsFixturePrefix = "analyzer/src/tester/";
	list[str] fixtureLines;
	if (isEdwardLaptop) {
		pathPrefix = |file:///Users/Edward/eclipse/workspace/Assignment%201/|;
		fixtureLines = readFileLines(pathPrefix + resultsFixturePrefix + "resultFixtureEdward.txt");
	}
	else {
		pathPrefix = |file:///C:/Users/Olav/Documents/Software%20Engineering/Software%20Evolution/software-evolution|;
		fixtureLines = readFileLines(pathPrefix + resultsFixturePrefix + "resultFixtureOlav.txt");
	}
		
	loc javaTestFiles = (pathPrefix + "analyzerTestCases");
	main(javaTestFiles);
	list[str] outputFileLines = readFileLines(pathPrefix + "analyzerTestCases/resultOfAnalysis.txt");
	
	if (fixtureLines != outputFileLines) {
		throw AssertionFailed("Fixture output file not equal to generated output file");
	}
	else {
		println("No issues encountered.");
	}
}
