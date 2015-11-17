module CodeDuplicationAnalyzer

import String;
import List;
import IO;

private loc fileLocation;

private real duplicationVolume;

public void setLocation(loc location) {
	fileLocation = location;
}

public real getDuplicationVolume() {
	return duplicationVolume;
}

/**
 * Calculate the score for code duplication of all sourcefiles in a location.
 * -2 represents --, -1 represents -, 0 represents 0, 1 represents + and 2 represents ++.
 * This representation was implemented to be able to perform calculations with the rankings.
 */
 public int calculateCodeDuplicationRank() {
 	duplicationVolume = getDuplicationPercentageForLocation();

 	if (duplicationVolume < 3)
 		return 2;
	if (duplicationVolume < 5)
		return 1;
	if (duplicationVolume < 10)
		return 0;
	if (duplicationVolume < 20)
		return -1;
	return -2;
 }

public real getDuplicationPercentageForLocation() {
	list[str] linesWithoutCommentsInAllFiles = getSourceLinesInAllJavaFiles();
	map[str, bool] blocksOfSixConsecutiveLines = ();
	int numberOfDuplicates = 0;
	int blocksFound = 0;
	
	if (size(linesWithoutCommentsInAllFiles) - 5 > 0)
	{
		for (int i <- [0..(size(linesWithoutCommentsInAllFiles) - 5)]) {
			list[str] blockOfSixLines = linesWithoutCommentsInAllFiles[i..(i + 6)];
			// use string as key because no hashing function present in rascal, maps do actually hash keys so using concat of string as key works also
			str sixLinesAsKey = blockOfSixLines[0] + blockOfSixLines[1] + blockOfSixLines[2] + blockOfSixLines[3] + blockOfSixLines[4] + blockOfSixLines[5];
			if (sixLinesAsKey in blocksOfSixConsecutiveLines && !blocksOfSixConsecutiveLines[sixLinesAsKey]) {
				numberOfDuplicates += 1;
				blocksOfSixConsecutiveLines[sixLinesAsKey] = true;
			}
			else {
				// only add when it is not present yet, adding twice adds no value
				blocksOfSixConsecutiveLines[sixLinesAsKey] = false;
			}
			blocksFound += 1;
		}
		return ((numberOfDuplicates * 1.0) / blocksFound) * 100;
	}
	
	return 0.0;
}

/*
 * For a given location, get all source lines contained in files at that location.
 * These are the actual source code lines, not based on our interpretation of the AST
 * of those files. The latter is done in the locToLines() function.
 */
public list[str] getSourceLinesInAllJavaFiles() {
    list[loc] allFileLocations = allFilesAtLocation();
    list[str] allLinesInFiles = ([] | it + linesInFile | linesInFile <- mapper(allFileLocations, readFileLines));
	return linesWithoutCommentsInAllFiles = stripCommentsInLines(allLinesInFiles);
}

/*
 * When passed a list of all lines in files, strips comments out of it.
 */
public list[str] stripCommentsInLines(list[str] allLines) {
    // defines if we are in the content of a multi line comment
    bool inMultiLineComment = false;
 	
    return for (str line <- allLines) {
    	if (inMultiLineComment) {
	    	if (/\A<beforeComment:.*>\*\/\s*<code:(.*)>\z/ := line
	    	&& (size(findAll(beforeComment, "\""))) % 2 == 0) {
	    		if (!isEmpty(code)) {
	    			append code;
	    		}
	    		
	    		inMultiLineComment = false;
	    	}
    	}
    	// line of form [code] // [comment]
    	else if (/\A\s*<code:(.*?)>\s*\/\/.*\z/ := line
    	&& (size(findAll(code, "\""))) % 2 == 0) {
    		if (!isEmpty(code)) {
	    		append code;
	    	}
    	} 
    	// line of form [code1] /* [comment] */ [code2]
    	else if (/\A\s*<code1:(.*?)>\s*\/\*.*\*\/\s*<code2:(.*)>\z/ := line
    	&& (size(findAll(code1, "\""))) % 2 == 0 && (size(findAll(code2, "\""))) % 2 == 0) {
    		if (!isEmpty(code1)) {
	    		append code1;
	    	}
	    	if (!isEmpty(code2)) {
	    		for(lineInCode2 <- stripCommentsInLines([code2])) {
	    			append lineInCode2;
	    		}
	    	}	
    	}
    	// line of form [code] /* [comment]
    	else if (/\A\s*<code:(.*?)>\s*\/\*.*\z/ := line && (size(findAll(code, "\""))) % 2 == 0) {
    		inMultiLineComment = true;
		
			if (!isEmpty(code)) {
    			append code;
    		}
    	}
    	// consists of any amount of whitespace plus optional code block
    	else if(/\A\s*<code:(.*)>\z/ := line) {
    		// check if code block exists before adding
    		if (!isEmpty(code)) {
	    		append code;
    		}
    	}
    }
}

public list[loc] allFilesAtLocation() {
	return allFilesAtLocation(fileLocation);
}

/*
 * For a given location, recursively find all Java files contained in it.
 */
public list[loc] allFilesAtLocation(loc location) {
	if (isDirectory(location)) {
		list [loc] allLocationContents = location.ls;		
		list [loc] files = [];
		
		for(loc fileOrDir <- allLocationContents) {
			if (isDirectory(fileOrDir)) {
				// recurse on subdirectory
				files += allFilesAtLocation(fileOrDir);
			} 
			else {
				// only add Java files to file list
				str lastSegmentInPath = fileOrDir.file;
				if (/.*\.java/ :=  lastSegmentInPath) {
					files += fileOrDir;
				}
			}
		}
		return files;
	} 
	else {
		return [location];
	} 
}