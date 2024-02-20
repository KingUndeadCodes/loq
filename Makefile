all: build clean

# nohup cat file.loq | ./a.out &
# pid=$(pgrep -f "a.out")
# rss=$(ps -o rss -p $pid | awk 'NR>1')
# echo "Memory Usage: ${rss} KB"

run:
	time cat file.loq | ./a.out

test: run

# Without -O3, It will be very slow.
build: lex.yy.c y.tab.c
	g++ -g -O3 lex.yy.c y.tab.c -ferror-limit=100

lex.yy.c: y.tab.c lexer.l
	lex lexer.l

y.tab.c: parser.y
	yacc -d parser.y

clean: 
	rm -rf lex.yy.c y.tab.c y.tab.h a.out.dSYM