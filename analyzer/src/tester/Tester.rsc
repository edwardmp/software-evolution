module tester::Tester

import Analyzer;
import IO;
import Exception;

public void runTests(bool isEdwardLaptop) {
	loc pathPrefix;
	list[str] fixtureLines;
	if (isEdwardLaptop) {
		pathPrefix = |file:///Users/Edward/eclipse/workspace/Assignment%201/|;
		fixtureLines = readFileLines(pathPrefix + "analyzer/src/tester/resultFixtureEdward.txt");
	}
	else {
		pathPrefix = |file:///C:/Users/Olav/Documents/Software%20Engineering/Software%20Evolution/software-evolution|;
		fixtureLines = readFileLines(pathPrefix + "analyzer/src/tester/resultFixtureOlav.txt");
	}
		
	loc javaTestFiles = (pathPrefix + "analyzerTestCases");
	main(javaTestFiles);
	list[str] outputFileLines = readFileLines(pathPrefix + "AnalyzerTestCases/resultOfAnalysis.txt");
	
	if (fixtureLines != outputFileLines) {
		throw AssertionFailed("Fixture output file not equal to generated output file");
	}
	else {
		println("No issues encountered.");
	}
}
