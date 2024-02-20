all: build clean

run:
	./a.out

build: lex.yy.c y.tab.c
	g++ -g -O3 lex.yy.c y.tab.c `llvm-config --cxxflags` -ferror-limit=100

lex.yy.c: y.tab.c lexer.l
	lex lexer.l

y.tab.c: parser.y
	yacc -d parser.y

clean: 
	rm -rf lex.yy.c y.tab.c y.tab.h a.out.dSYM