module tester::Tester

import Analyzer;
import IO;
import Exception;

public void runTests() {
	loc javaTestFiles = (|file:///Users/Edward/eclipse/workspace/Assignment%201/AnalyzerTestCases|);
	main(javaTestFiles);
	list[str] fixtureLines = readFileLines(|file:///Users/Edward/eclipse/workspace/Assignment%201/analyzer/src/tester/resultFixture.txt|);
	list[str] outputFileLines = readFileLines(|file:///Users/Edward/eclipse/workspace/Assignment%201/AnalyzerTestCases/resultOfAnalysis.txt|);
	
	if (fixtureLines != outputFileLines) {
		throw AssertionFailed("Fixture output file not equal to generated output file");
	}
}
