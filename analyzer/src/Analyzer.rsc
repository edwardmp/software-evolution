module Analyzer

import List;
import lang::java::m3::AST;

public list[Declaration] locToAsts(loc location) {
	return createAstsFromDirectory(location, true);
}

public void astsToLines(list[Declaration] decs)
{
	return ([] | it + dec | dec <- mapper(decs, declarationToLines));
}

public list[value] locToLines(loc location) {
	return astsToLines(locToAsts(location));
}

public list[value] declarationToLines(Declaration ast)
{	
	switch (ast) {
		case \compilationUnit(list[Declaration] imports, list[Declaration] types):
			return imports + ([] | it + x | x <- mapper(types, declarationToLines));
		case \compilationUnit(Declaration package, list[Declaration] imports, list[Declaration] types):
			return package + imports + ([] | it + x | x <- mapper(types, declarationToLines));
		case \enum(str name, list[Type] implements, list[Declaration] constants, list[Declaration] body):
			return "{" + implements + constants + ([] | it + x | x <- mapper(body, declarationToLines)) + "}";
		case \class(str name, list[Type] extends, list[Type] implements, list[Declaration] body):
			{
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
		case \method(Type \return, str name, list[Declaration] parameters, list[Expression] exceptions, Statement impl):
			return exceptions + statementToLines(impl);
		case \method(Type \return, str name, list[Declaration] parameters, list[Expression] exceptions):
			return name + exceptions; // recheck
		case \constructor(str name, list[Declaration] parameters, list[Expression] exceptions, Statement impl):
			return exceptions + statementToLines(impl);
		default:
			return [];
	}
}

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
		case \do(Statement body, Expression condition):
			return statementToLines(body);
		case \foreach(Declaration parameter, Expression collection, Statement body):
			return statementToLines(body);
		case \for(list[Expression] initializers, Expression condition, list[Expression] updaters, Statement body):
			return statementToLines(body);
		case \for(list[Expression] initializers, list[Expression] updaters, Statement body):
			return statementToLines(body);
		case \if(Expression condition, Statement thenBranch):
			return statementToLines(thenBranch);
		case \if(Expression condition, Statement thenBranch, Statement elseBranch):
			return statementTolInes(thenBranch) + statementToLines(elseBranch);
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
    	case \while(Expression condition, Statement body):
    		return statementToLines(body);
    	default:
    		return [];
	}
}
