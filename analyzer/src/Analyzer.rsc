module Analyzer

import Exception;
import List;
import Map;
import Set;
import String;
import lang::java::m3::AST;
import IO;

/*
 * A map containing the lines in each method, after locToLines has been run.
 */
private map[str, map[str, list[value]]] linesPerMethod = ();

/*
 * Indicates whether analysis has been run and lines per method can be obtained.
 */
private bool analysisRan = false;

/*
 * A map containing the cyclomatic complexity for each method, after locToLines has been run.
 */
private map[str, map[str, int]] numberOfConditionsEncounteredPerMethod = ();

/*
 * A string that saves the currently investigated method for the complexity.
 */
private str activeMethod = "";

private str activeClass = "";

private int totalVolume = 0;

/**
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
 
 public int calculateUnitSizeRank() {
 	map [str, map[str, int]] numberOfLinesPerMethod = numberOfLinesPerMethod();
 
 	map [str, map[str, int]] unitSizeRiskCategoryPerMethod = ();
 	
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

/**
 * Calculate the score for code duplication of all sourcefiles in a location.
 * -2 represents --, -1 represents -, 0 represents 0, 1 represents + and 2 represents ++.
 * This representation was implemented to be able to perform calculations with the rankings.
 */
 public int calculateCodeDuplicationRank(loc location) {
 	real volume = getDuplicationPercentageForLocation(location);

 	if (volume < 3)
 		return 2;
	if (volume < 5)
		return 1;
	if (volume < 10)
		return 0;
	if (volume < 20)
		return -1;
	return -2;
 }

/*
 * Calculate the volume of all sourcefiles in a location.
 * The location must be specified using the file-scheme.
 */
// check if loctolines is ran
public int calculateVolume(){
	if (analysisRan) {
		return totalVolume;
	}
	else {
		throw AssertionFailed("Analysis not ran. Run locToLines first.");
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
public list[value] locToLines(loc location) {
	list[value] lines = astsToLines(locToAsts(location));
	analysisRan = true;
	
	totalVolume = size(lines);
	return lines;
}

/*
 * Get a list of the lines in a set of Declarations (ASTs) the way they
 * are represented in the ASTs.
 */
public list[value] astsToLines(set[Declaration] decs)
{
	return ([] | it + dec | dec <- mapper(decs, declarationToLines));
}

/*
 * Get a list of the lines in a Declaration (AST) the way they are
 * represented in the AST.
 */
public list[value] declarationToLines(Declaration ast)
{	
	switch (ast) {
		case \compilationUnit(list[Declaration] imports, list[Declaration] types):
			return imports + ([] | it + x | x <- mapper(types, declarationToLines));
		case \compilationUnit(Declaration package, list[Declaration] imports, list[Declaration] types):
			return package + imports + ([] | it + x | x <- mapper(types, declarationToLines));
		case \enum(str name, list[Type] implements, list[Declaration] constants, list[Declaration] body):
			return "{" + implements + constants + ([] | it + x | x <- mapper(body, declarationToLines)) + "}";
		case \class(str name, list[Type] extends, list[Type] implements, list[Declaration] body): {
			str previousActiveClass = activeClass;
			activeClass = name;
			
			list[value] extImpl = extends + implements;
			
			list[value] result;
			if (isEmpty(extImpl)) {
				result = "{" + ([] | it + x | x <- mapper(body, declarationToLines)) + "}";
			}
			else {
				result = extImpl + ([] | it + x | x <- mapper(body, declarationToLines)) + "}";
			}
			
			activeClass = previousActiveClass;
			return result;
		}
		case \class(list[Declaration] body):
			return "{" + ([] | it + x | x <- mapper(body, declarationToLines)) + "}";
		case \interface(str name, list[Type] extends, list[Type] implements, list[Declaration] body):
			return extends + implements + "{" + ([] | it + x | x <- mapper(body, declarationToLines)) + "}";
		case f:\field(Type \type, list[Expression] fragments):
			return [f];
		case \initializer(Statement initializerBody):
			return statementToLines(initializerBody);
		case \method(Type \return, str name, list[Declaration] parameters, list[Expression] exceptions, Statement impl):
			return handleMethodOrConstructor(name, impl, exceptions);
		case \method(Type \return, str name, list[Declaration] parameters, list[Expression] exceptions):
			return name + exceptions; // recheck
		case \constructor(str name, list[Declaration] parameters, list[Expression] exceptions, Statement impl):
			return handleMethodOrConstructor(name, impl, exceptions);
		case \variables(Type \type, list[Expression] \fragments):
		{
			for (Expression expr <- \fragments) {
				handleExpression(expr);
			}
			return [];
		}
		default:
			return [];
	}
}

/*
 * Wrapper for evaluation code common to both (non-abstract) methods and constructors.
 */
public list[value] handleMethodOrConstructor(str nameOfMethod, Statement impl,  list[Expression] exceptions) {
	str previousActiveMethod = activeMethod;
	activeMethod = nameOfMethod;
	
	// initialize empty map for that class name
	if (activeClass notin numberOfConditionsEncounteredPerMethod)
		numberOfConditionsEncounteredPerMethod += (activeClass: ());
		
	numberOfConditionsEncounteredPerMethod[activeClass] += (activeMethod : 1);
	list[value] body = statementToLines(impl);
	
	activeMethod = previousActiveMethod;

	if (activeClass notin linesPerMethod)
		linesPerMethod += (activeClass: ());
		
	linesPerMethod[activeClass] += (nameOfMethod : body);
	
	return exceptions + body;
}

/*
 * Get a list of lines in a Statement.
 */
public list[value] statementToLines(Statement statement) {
	switch (statement) {
	 	case \empty():
   			return [];
		/* Oneliners */
		case a:\assert(Expression expression): {
			handleExpression(expression);
			return [a];
		}
		case a:\assert(Expression expression, Expression message): {
			handleExpression(expression);
			handleExpression(message);
			return [a];
		}
		case b:\break():
			return [b];
		case b:\break(str label):
			return [b];
		case c:\continue():
			return [c];
		case c:\continue(str label):
			return [c];
		case l:\label(str name, Statement body):
			return [l];
		case r:\return(Expression expression): {
		handleExpression(expression);
			return [r];
		}
		case r:\return():
			return [r];
		case c:\case(Expression expression): {
			handleExpression(expression);
			return [c];
		}
		case d:\defaultCase():
			return [d];
		case t:\throw(Expression expression): {
			handleExpression(expression);
			return [t];
		}
		case d:\declarationStatement(Declaration declaration):
		{
			declarationToLines(declaration);
			return [d];
		}
		case c:\constructorCall(bool isSuper, Expression expr, list[Expression] arguments): {
			for (Expression epxression <- expr + arguments) {
				handleExpression(expression);
			}
			return [c];
		}
   		case c:\constructorCall(bool isSuper, list[Expression] arguments): {
   			for (Expression expression <- arguments) {
				handleExpression(expression);
			}
   			return [c];
   		}
   		/* Multiliners */
		case e:\expressionStatement(Expression stmt): {
			handleExpression(stmt);
			return [e];
		}
		case b:\block(list[Statement] statements):
			return "{" +  ([] | it + x | x <- mapper(statements, statementToLines)) + "}";
		case \do(Statement body, Expression condition): {
			if (activeMethod != "")
				numberOfConditionsEncounteredPerMethod[activeClass][activeMethod] += countConditions(condition);
			
			handleExpression(condition);
			return statementToLines(body);
		}
		case \foreach(Declaration parameter, Expression collection, Statement body): {
			handleExpression(collection);
			return statementToLines(body);
		}
		case \for(list[Expression] initializers, Expression condition, list[Expression] updaters, Statement body): {
			if (activeMethod != "")
				numberOfConditionsEncounteredPerMethod[activeClass][activeMethod] += countConditions(condition);
			
			for (Expression expr <- initializers + condition + updaters) {
				handleExpression(expr);
			}
			return statementToLines(body);
		}
		case \for(list[Expression] initializers, list[Expression] updaters, Statement body): {
			for (Expression expr <- initializers + updaters) {
				handleExpression(expr);
			}
			return statementToLines(body);
		}
		case \if(Expression condition, Statement thenBranch): {
			if (activeMethod != "")
				numberOfConditionsEncounteredPerMethod[activeClass][activeMethod] += countConditions(condition);
			
			handleExpression(condition);
			return statementToLines(thenBranch);
		}
		case \if(Expression condition, Statement thenBranch, Statement elseBranch): {
			if (activeMethod != "")
				numberOfConditionsEncounteredPerMethod[activeClass][activeMethod] += countConditions(condition);
			
			handleExpression(condition);
		
			list[value] thenBranchLines = statementToLines(thenBranch);
			
			value thenBranchLastLine = "";
			if (!isEmpty(thenBranchLines)) {
				thenBranchLastLine = last(thenBranchLines);
				thenBranchLines = delete(thenBranchLines, (size(thenBranchLines) - 1));
			}
			
			list[value] elseBranchLines =  statementToLines(elseBranch);
			
			value elseBranchFirstLine = "";
			if (!isEmpty(elseBranchLines)) {
				elseBranchFirstLine = head(elseBranchLines);
				elseBranchLines = delete(elseBranchLines, 0);
			}
			
			if (thenBranchLastLine != "" && elseBranchFirstLine != "")
				return thenBranchLines + <thenBranchLastLine, elseBranchFirstLine> + elseBranchLines;
			else if (thenBranchLastLine != "")
				return thenBranchLines + thenBranchLastLine + elseBranchLines;
			else if (elseBranchFirstLine != "")
				return thenBranchLines + elseBranchFirstLine + elseBranchLines;
			else
				return thenBranchLines + elseBranchLines;
		}
		case \switch(Expression expression, list[Statement] statements): {
			if (activeMethod != "")
			{
				list[Statement] casesPlusDefault = [];
				for(Statement statement <- statements) {
					if (\case(Expression expression) := statement) {
						casesPlusDefault += statement;
					}
					else if  (\defaultCase() := statement) {
						casesPlusDefault += statement;
					}
				}
				
				int numberOfCases = size(casesPlusDefault);
				if (numberOfCases != 0)
					numberOfConditionsEncounteredPerMethod[activeClass][activeMethod] += (numberOfCases - 1);
			}
		
			handleExpression(expression);
			return "{" + ([] | it + x | x <- mapper(statements, statementToLines)) + "}";
		}
		case \synchronizedStatement(Expression lock, Statement body):
			return statementToLines(body);
		case \try(Statement body, list[Statement] catchClauses):
			return "{" + statementToLines(body) + "}" + ([] | it + x | x <- mapper(catchClauses, statementToLines));
    	case \try(Statement body, list[Statement] catchClauses, Statement \finally):
    		return statementToLines(body) + ([] | it + x | x <- mapper(catchClauses, statementToLines));
    	case \catch(Declaration exception, Statement body):
    		return statementToLines(body);
    	case \while(Expression condition, Statement body): {
    		if (activeMethod != "")
				numberOfConditionsEncounteredPerMethod[activeClass][activeMethod] += countConditions(condition);
			
			handleExpression(condition);
    		return statementToLines(body);
    	}
    	default:
    		return [];
	}
}

/*
 * Handle expressions, used for computing cyclomatic complexity.
 */
public void handleExpression(Expression expr) {
	if (activeMethod == "")
		return;
	
	switch(expr) {
		case \arrayAccess(Expression array, Expression index): {
			handleExpression(array);
			handleExpression(index);
		}
		case \newArray(Type \type, list[Expression] dimensions, Expression init): {
			for(expr <- dimensions + init)
				handleExpression(expr);
		}
		case \newArray(Type \type, list[Expression] dimensions): {
			for(expr <- dimensions)
				handleExpression(expr);
		}
		case \arrayInitializer(list[Expression] elements): {
			for(expr <- elements)
				handleExpression(expr);	
		}
		case \assignment(Expression lhs, str operator, Expression rhs): {
			handleExpression(lhs);
			handleExpression(rhs);
		}
		case \cast(Type \type, Expression expression): {
			handleExpression(expression);
		}
		case \newObject(Expression expr, Type \type, list[Expression] args, Declaration class): {
			for(expression <- expr + args)
				handleExpression(expression);
		}
		case \newObject(Expression expr, Type \type, list[Expression] args): {
			for(expression <- expr + args)
				handleExpression(expression);
		}
		case \newObject(Type \type, list[Expression] args, Declaration class): {
			for(expr <- args)
				handleExpression(expr);
		}
		case \newObject(Type \type, list[Expression] args): {
			for(expr <- args)
				handleExpression(expr);
		}
		case \qualifiedName(Expression qualifier, Expression expression): {
			handleExpression(qualifier);
			handleExpression(expression);
		}
		case \conditional(Expression expression, Expression thenBranch, Expression elseBranch):
		{
			handleExpression(thenBranch);
			handleExpression(elseBranch);
			numberOfConditionsEncounteredPerMethod[activeClass][activeMethod] += countConditions(expression);
		}
		case \fieldAccess(bool isSuper, Expression expression, str name): {
			handleExpression(expression);
		}
		case \instanceof(Expression leftSide, Type rightSide): {
			handleExpression(leftSide);
		}
		case \methodCall(bool isSuper, str name, list[Expression] arguments): {
			for(expr <- arguments)
				handleExpression(expr);
		}
		case \methodCall(bool isSuper, Expression receiver, str name, list[Expression] arguments): {
			for(expr <- receiver + arguments)
				handleExpression(expr);
		}
		case \variable(str name, int extraDimensions, Expression \initializer): {
			handleExpression(\initializer);
		}
		case \bracket(Expression expression): {
			handleExpression(expression);
		}
		case \this(Expression thisExpression): {
			handleExpression(thisExpression);
		}
		case \infix(Expression lhs, str operator, Expression rhs): {
			handleExpression(lhs);
			handleExpression(rhs);
		}
		case \postfix(Expression operand, str operator): {
			handleExpression(operand);
		}
		case \prefix(str operator, Expression operand): {
			handleExpression(operand);
		}
		case \memberValuePair(str name, Expression \value): {     
			handleExpression(\value);     
		}
		case \singleMemberAnnotation(str typeName, Expression \value): {
			handleExpression(\value);
		}
	}
}

/*
 * Given an Expression, count the number of logical conditions within it.
 */
public int countConditions(Expression expr) {
	switch (expr) {
		case \infix(Expression lhs, str operator, Expression rhs):
		{
			if (operator == "&&" || operator == "||" || operator == "|" || operator == "&" || operator == "^")
				return countConditions(lhs) + countConditions(rhs);
			else
				return 1;
		}
		default:
			return 1;
	}
}

/*
 * Get a set of Declarations (an AST) from a location.
 * The location must be a directory and must be specified
 * using the file-scheme. E.g. |file:///C:/Users/Test/My%20Documents/Test|.
 */
public set[Declaration] locToAsts(loc location) {
	return createAstsFromDirectory(location, false);
}

/**
 * Calculate the rank of complexity of all units at the analyzed location.
 * -2 represents --, -1 represents -, 0 represents 0, 1 represents + and 2 represents ++.
 * This representation was implemented to be able to perform calculations with the rankings.
 */
public int calculateUnitComplexityRank() {
	map[str, map[str, int]] complexities = getComplexityPerMethod();
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

public int generalSIGRankCalculator(map[int, real] percentageOfLinesInEachCategory) {
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

public map[int, real] generalCategoryPercentageCalculator(map [str, map[str, int]] riskForEachMethodInClass) {
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

/*
 * Returns a map from the name of each class, to a map from the name of
 * each method in that class to the lines in that method.
 */
public map[str, map[str, list[value]]] getListOfLinesPerMethod() {
	if (analysisRan) {
		return linesPerMethod;
	}
	else {
		throw AssertionFailed("Analysis not ran. Run locToLines first.");
	}
}

/*
 * Returns a map from the name of each class to a map from name of each method to 
 * the the number of lines for each method.
 */
public map[str, map[str, int]] numberOfLinesPerMethod() {
	if (analysisRan) {
		map[str, map[str, int]] result = ();
		for (class <- linesPerMethod) {
			// Minus 2 lines for the opening and closing bracket surrounding the method body
			result += (class : (() | it + (method : size(linesPerMethod[class][method]) - 2) | method <- linesPerMethod[class]));	
		}
		return result;	
	}
	else {
		throw AssertionFailed("Analysis not ran. Run locToLines first.");
	}
}

/*
 * Returns a map with the cyclomatic complexity,
 * mapped from the name of the method.
 */
public map[str, map[str, int]] getComplexityPerMethod() {
	if (analysisRan) {
		return numberOfConditionsEncounteredPerMethod;
	}
	else {
		throw AssertionFailed("Analysis not ran. Run locToLines first.");
	}
}

public real getDuplicationPercentageForLocation(loc location) {
	list[str] linesWithoutCommentsInAllFiles = getSourceLinesInAllJavaFiles(location);
	map[str, bool] blocksOfSixConsecutiveLines = ();
	int numberOfDuplicates = 0;
	int blocksFound = 0;
	for (int i <- [0..(size(linesWithoutCommentsInAllFiles) - 5)]) {
		list[str] blockOfSixLines = linesWithoutCommentsInAllFiles[i..(i + 6)];
		// use string as key because no hashing function present in rascal, maps hash keys so using concat of string as key works also
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

/*
 * For a given location, get all source lines contained in files at that location.
 * These are the actual source code lines, not based on our interpretation of the AST
 * of those files. The latter is done in the locToLines() function.
 */
public list[str] getSourceLinesInAllJavaFiles(loc project) {
    list[loc] allFileLocations = allFilesAtLocation(project);
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
    	else if (/\A\s*<code:(.*?)>\s*\/\/.*\z/ := line) {
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
