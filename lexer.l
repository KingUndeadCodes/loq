%{
#include "y.tab.h"
void yyerror (char *s);
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
.          { ECHO; fprintf(stderr, "unexpected character: %c\n", yytext[0]); }
%%

int yywrap(void) {
    // yylex();
    return 1;
}