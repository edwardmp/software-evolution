module tester::Tester

import Analyzer;
import IO;
import Exception;

public void runTests(bool isEdwardLaptop) {
	loc pathPrefix;
	if (isEdwardLaptop) {
		pathPrefix = |file:///Users/Edward/eclipse/workspace/Assignment%201/|;
	}
	else {
		pathPrefix = |file:///C:/Users/Olav/Documents/Software%20Engineering/Software%20Evolution/software-evolution|;
	}
		
	loc javaTestFiles = (pathPrefix + "analyzerTestCases");
	main(javaTestFiles);
	list[str] fixtureLines = readFileLines(pathPrefix + "analyzer/src/tester/resultFixture.txt");
	list[str] outputFileLines = readFileLines(pathPrefix + "AnalyzerTestCases/resultOfAnalysis.txt");
	
	if (fixtureLines != outputFileLines) {
		throw AssertionFailed("Fixture output file not equal to generated output file");
	}
}
