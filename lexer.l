%{
#include "y.tab.h"
int yylex();
int line_number = 1;
// {I}        { yylval.id = strdup(yytext); return Identifier; }
// "print"    return print;
%}

%option nounput yylineno

I [a-zA-Z_][a-zA-Z0-9_]*
D [0-9]+
S \"(\\.|[^"\\])*\"

%%
"//".*                              ; // C Comment "// Comment"
"/*"[^*]*"*"("*"|[^*/][^*]*"*")*"/" ; // C Comment "/* Comment */"
"print"    return print;
"=="       return EQU;
"!="       return NEQ;
"<="       return LET;
">="       return GET;
"$"        return yytext[0];
"?"        return yytext[0];
":"        return yytext[0];
"["        return yytext[0];
"]"        return yytext[0];
"{"        return yytext[0];
"}"        return yytext[0];
"("        return yytext[0];
")"        return yytext[0];
"+"        return yytext[0];
"-"        return yytext[0];
"*"        return yytext[0];
"/"        return yytext[0];
"%"        return yytext[0];
"&"        return yytext[0];
"|"        return yytext[0];
"^"        return yytext[0];
"~"        return yytext[0];
"="        return yytext[0];
">"        return yytext[0];
"<"        return yytext[0];
","        return yytext[0];
";"        return yytext[0];
[ \t\n]    ;
{I}        { yylval.id = strdup(yytext); return Identifier; }
{D}        { yylval.num = atoi(yytext); return Number; }
.          { ECHO; fprintf(stderr, "[\033[1;37mLexer\033[0m] \033[1;31mError\033[0m: unexpected character: \"%c\"\n", yytext[0]); exit(1); } // Create a llwarn function.
%%

int yywrap(void) {
    // yylex();
    return 1;
}