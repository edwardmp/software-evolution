module Analyzer

import lang::java::m3::AST;
import IO;

public Declaration astTest() {
	Declaration ast = createAstFromFile(|project://analyzer/src/Test.java|, true);
	//println(ast);
	return ast;
}