module Analyzer

import Exception;
import List;
import Map;
import Set;
import String;
import lang::java::m3::AST;

/*
 * A map containing the lines in each method, after locToLines has been run.
 */
private map[str, list[value]] linesPerMethod = ();

/*
 * Indicates whether analysis has been run and lines per method can be obtained.
 */
private bool analysisRan = false;

/*
 * A map containing the cyclomatic complexity for each method, after locToLines has been run.
 */
private map[str, int] numberOfConditionsEncounteredPerMethod = ();

/*
 * A string that saves the currently investigated method for the complexity.
 */
private str activeMethod = "";

/*
 * Calculate the volume of all sourcefiles in a location.
 * The location must be specified using the file-scheme.
 */
public int calculateVolume(loc location) = size(locToLines(location));

/*
 * Get a list of the lines in all sourcefiles in a location, the way they
 * are represented in an AST. The location must be specified using the
 * file-scheme.
 */
public list[value] locToLines(loc location) {
	list[value] lines = astsToLines(locToAsts(location));
	analysisRan = true;
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
			list[value] extImpl = extends + implements;
			
			if (isEmpty(extImpl)) {
				return "{" + ([] | it + x | x <- mapper(body, declarationToLines)) + "}";
			}
			else {
				return extImpl + ([] | it + x | x <- mapper(body, declarationToLines)) + "}";
			}
		}
		case \class(list[Declaration] body):
			return "{" + ([] | it + x | x <- mapper(body, declarationToLines)) + "}";
		case \interface(str name, list[Type] extends, list[Type] implements, list[Declaration] body):
			return extends + implements + "{" + ([] | it + x | x <- mapper(body, declarationToLines)) + "}";
		case f:\field(Type \type, list[Expression] fragments):
			return [f];
		case \initializer(Statement initializerBody):
			return statementToLines(initializerBody);
		case \method(Type \return, str name, list[Declaration] parameters, list[Expression] exceptions, Statement impl): {
			return handleMethodOrConstructor(name, impl, exceptions);
		}
		case \method(Type \return, str name, list[Declaration] parameters, list[Expression] exceptions):
			return name + exceptions; // recheck
		case \constructor(str name, list[Declaration] parameters, list[Expression] exceptions, Statement impl): {
			return handleMethodOrConstructor(name, impl, exceptions);
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
	
	numberOfConditionsEncounteredPerMethod += (activeMethod : 1);
	list[value] body = statementToLines(impl);
	
	activeMethod = previousActiveMethod;
	linesPerMethod += (nameOfMethod : body);
	
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
		case a:\assert(Expression expression):
			return [a];
		case a:\assert(Expression expression, Expression message):
			return [a];
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
		case r:\return(Expression expression):
			return [r];
		case r:\return():
			return [r];
		case c:\case(Expression expression):
			return [c];
		case d:\defaultCase():
			return [d];
		case t:\throw(Expression expression):
			return [t];
		case d:\declarationStatement(Declaration declaration):
			return [d];
		case c:\constructorCall(bool isSuper, Expression expr, list[Expression] arguments):
			return [c];
   		case c:\constructorCall(bool isSuper, list[Expression] arguments):
   			return [c];
   		/* Multiliners */
		case e:\expressionStatement(Expression stmt):
			return [e];
		case b:\block(list[Statement] statements):
			return "{" +  ([] | it + x | x <- mapper(statements, statementToLines)) + "}";
		case \do(Statement body, Expression condition): {
			if (activeMethod != "")
				numberOfConditionsEncounteredPerMethod[activeMethod] += countConditions(condition);
				
			return statementToLines(body);
		}
		case \foreach(Declaration parameter, Expression collection, Statement body):
			return statementToLines(body);
		case \for(list[Expression] initializers, Expression condition, list[Expression] updaters, Statement body): {
			if (activeMethod != "")
					numberOfConditionsEncounteredPerMethod[activeMethod] += countConditions(condition);
					
			return statementToLines(body);
		}
		case \for(list[Expression] initializers, list[Expression] updaters, Statement body):					
			return statementToLines(body);
		case \if(Expression condition, Statement thenBranch): {
			if (activeMethod != "")
				numberOfConditionsEncounteredPerMethod[activeMethod] += countConditions(condition);
				
			return statementToLines(thenBranch);
		}
		case \if(Expression condition, Statement thenBranch, Statement elseBranch): {
			if (activeMethod != "")
				numberOfConditionsEncounteredPerMethod[activeMethod] += countConditions(condition);
					
			return statementToLines(thenBranch) + statementToLines(elseBranch);
		}
		case \switch(Expression expression, list[Statement] statements):
			return "{" + ([] | it + x | x <- mapper(statements, statementToLines)) + "}";
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
				numberOfConditionsEncounteredPerMethod[activeMethod] += countConditions(condition);
				
    		return statementToLines(body);
    	}
    	default:
    		return [];
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
	return createAstsFromDirectory(location, true);
}

/*
 * Returns a map with a list of the lines for each method,
 * mapped from the name of the method.
 */
public map[str,list[value]] getLinesPerMethod() {
	if (analysisRan) {
		return linesPerMethod;
	}
	else {
		throw AssertionFailed("Analysis not ran. Run locToLines first.");
	}
}

/*
 * Returns a map with the number of lines for each method,
 * mapped from the name of the method.
 */
public map[str,int] numberOfLinesPerMethod() {
	if (analysisRan) {
		// Minus 2 lines for the opening and closing bracket surrounding the method body
		return (() | it + (method : size(linesPerMethod[method]) - 2) | method <- linesPerMethod);
	}
	else {
		throw AssertionFailed("Analysis not ran. Run locToLines first.");
	}
}

/*
 * Returns a map with the cyclomatic complexity,
 * mapped from the name of the method.
 */
public map[str, int] getComplexityPerMethod() {
	if (analysisRan) {
		return numberOfConditionsEncounteredPerMethod;
	}
	else {
		throw AssertionFailed("Analysis not ran. Run locToLines first.");
	}
}