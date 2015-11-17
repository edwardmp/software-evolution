module ASTTraverser

import lang::java::m3::AST;
import List;
import Set;
import IO;

/*
 * A map containing the cyclomatic complexity for each method, after locToLines has been run.
 */
private map[str, map[str, int]] numberOfConditionsEncounteredPerMethod = ();

/*
 * A string that saves the currently investigated method for the complexity.
 */
private str activeMethod = "";

private str activeClass = "";

private loc fileLocation;

private map[str, map[str, list[value]]] linesPerMethod = ();

public void setLocation(loc location) {
	fileLocation = location;
}

public void setLinesPerMethod(map[str, map[str, list[value]]] linesForEachMethod) {
	linesPerMethod = linesForEachMethod;
}

public map[str, map[str, list[value]]] getLinesPerMethod()
{
	return linesPerMethod;
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
		case \enum(str name, list[Type] implements, list[Declaration] constants, list[Declaration] body): {
			str previousActiveClass = activeClass;
			activeClass = name;
			list[value] result = "{" + implements + constants + ([] | it + x | x <- mapper(body, declarationToLines)) + "}";
			activeClass = previousActiveClass;
			return result;
		}
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
			
			return whenStatementNotBlockAddCondition(body, condition);
		}
		case \foreach(Declaration parameter, Expression collection, Statement body): {
			handleExpression(collection);
			return whenStatementNotBlockAddCondition(body, collection);
		}
		case \for(list[Expression] initializers, Expression condition, list[Expression] updaters, Statement body): {
			if (activeMethod != "")
				numberOfConditionsEncounteredPerMethod[activeClass][activeMethod] += countConditions(condition);
			
			for (Expression expr <- initializers + condition + updaters) {
				handleExpression(expr);
			}
			
			return whenStatementNotBlockAddCondition(body, condition);
		}
		case \for(list[Expression] initializers, list[Expression] updaters, Statement body): {
			for (Expression expr <- initializers + updaters) {
				handleExpression(expr);
			}
			return whenStatementNotBlockAddCondition(body, initializers[0]);
		}
		case \if(Expression condition, Statement thenBranch): {
			if (activeMethod != "")
				numberOfConditionsEncounteredPerMethod[activeClass][activeMethod] += countConditions(condition);
			
			handleExpression(condition);
			
			return whenStatementNotBlockAddCondition(thenBranch, condition);
		}
		case \if(Expression condition, Statement thenBranch, Statement elseBranch): {
			if (activeMethod != "")
				numberOfConditionsEncounteredPerMethod[activeClass][activeMethod] += countConditions(condition);
			
			handleExpression(condition);
		
			list[value] thenBranchLines = whenStatementNotBlockAddCondition(thenBranch, condition);
			
			value thenBranchLastLine = "";
			if (!isEmpty(thenBranchLines)) {
				thenBranchLastLine = last(thenBranchLines);
				thenBranchLines = delete(thenBranchLines, (size(thenBranchLines) - 1));
			}
			
			list[value] elseBranchLines = whenStatementNotBlockAddCondition(elseBranch, condition);
			
			value elseBranchFirstLine = "";
			if (!isEmpty(elseBranchLines)) {
				elseBranchFirstLine = head(elseBranchLines);
				elseBranchLines = delete(elseBranchLines, 0);
			}
			
			if (thenBranchLastLine != "" && elseBranchFirstLine != "") {
				if (\block(_) := thenBranch)
					return thenBranchLines + <thenBranchLastLine, elseBranchFirstLine> + elseBranchLines;
				else
					return thenBranchLines + thenBranchLastLine + elseBranchFirstLine + elseBranchLines;
			}
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
    		return whenStatementNotBlockAddCondition(body, condition);
    	}
    	default:
    		return [];
	}
}

public bool statementIsBlock(Statement statement) {
	return block(_) := statement;
}

public list[value] whenStatementNotBlockAddCondition(Statement statement, Expression condition) {
	if (statementIsBlock(statement)) {
		return statementToLines(statement);
	}
	else {
		return condition + statementToLines(statement);
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
 * using the file-scheme. E.g. |file:///C:/Users/Test/
ts/Test|.
 */
public set[Declaration] locToAsts() {
	if (isFile(fileLocation))
		return { createAstFromFile(fileLocation, false) };
	else
		return createAstsFromDirectory(fileLocation, false);
}

/*
 * Returns a map with the cyclomatic complexity,
 * mapped from the name of the method.
 */
public map[str, map[str, int]] complexityPerMethod() {
	return numberOfConditionsEncounteredPerMethod;
}