// Complete this file... Add functions
%{
    #include <map>
    #include <vector>
    #include <string>
    #include <math.h>
    #include <cstdlib>
    #include <stdlib.h>
    #include <stdint.h>
    #include <string.h>
    #include <stdio.h>
    extern int yylineno;
    extern char *yytext;
    extern FILE *yyin;
    int yylex();
    // Basically `bc` but based.
    // https://silcnitc.github.io/ywl.html
    // https://stackoverflow.com/questions/780676/string-input-to-flex-lexer
    // https://www.quut.com/c/ANSI-C-grammar-l.html
    void yyerror(const char *msg) { fprintf(stderr, "[\033[1;37mParser\033[0m] \033[1;31mError\033[0m <line: %d>: %s\n", yylineno, msg); exit(1); }
    void yywarn(const char *msg) { fprintf(stderr, "[\033[1;37mParser\033[0m] \033[1;33mWarning\033[0m <line: %d>: %s\n", yylineno, msg); }
    void yynote(const char *msg) { fprintf(stderr, "[\033[1;37mParser\033[0m] \033[1;33mNote\033[0m <line: %d>: %s\n", yylineno, msg); }
    struct node {
        int32_t value;
        char* id;
        char* op; 
        struct node* left;
        struct node* middle;
        struct node* right;
    };
    struct function {
        std::vector<std::string> parameters;
        struct node* nodes;
    };
    /* static std::map<int, std::vector<std::string> > func_map; */
    static std::map<int, int> var_map;
    static std::unordered_map<int, bool> is_func_map;
    static std::unordered_map<int, std::string> var_int_map; // Just to hold the name
    static std::unordered_map<std::string, int> var_str_map; // Reverse of `var_int_map`
    static std::unordered_map<int, struct function> var_func_map;
    struct node* makeOperatorNodeAdvanced(char c, struct node *l, struct node *m, struct node *r) {
        struct node *temp;
        temp = (struct node*)malloc(sizeof(struct node));
        temp->op = (char*)malloc(sizeof(char));
        temp->right = r;
        temp->left = l;
        temp->middle = m;
        *(temp->op) = c;
        temp->id = NULL;
        return temp;
    }
    struct node* makeOperatorNode(char c, struct node *l, struct node *r) {
        struct node *temp;
        temp = (struct node*)malloc(sizeof(struct node));
        temp->op = (char*)malloc(sizeof(char));
        temp->right = r;
        temp->left = l;
        temp->middle = NULL;
        *(temp->op) = c;
        temp->id = NULL;
        return temp;
    };
    struct node* makeLeafNode(int n) {
        struct node *temp;
        temp = (struct node*)malloc(sizeof(struct node));
        temp->op = NULL;
        temp->value = (int32_t)n;
        temp->left = NULL;
        temp->middle = NULL;
        temp->right = NULL;
        temp->id = NULL;
        return temp;
    };
    struct node* makeLeafNodeIdentifier(char *ident) {
        struct node *temp;
        temp = (struct node*)malloc(sizeof(struct node));
        temp->op = (char*)malloc(sizeof(char));
        temp->id = (char*)malloc(strlen(ident) * sizeof(char));
        temp->op = NULL;
        temp->left = NULL;
        temp->middle = NULL;
        temp->right = NULL;
        strcpy(temp->id, ident);
        return temp;
    };
    int id = 262144; // 2 ** 18
    int evaluate(struct node *t, bool return_var_id = false) {
        if (t->op == NULL) {
            if (t->id == NULL) {
                return t->value;
            }
            if (return_var_id == true) {
                return var_str_map[t->id];
            } else {
                return var_map[var_str_map[t->id]];
            }
        } else {
            struct node* left = t->left;
            struct node* middle = t->middle;
            struct node* right = t->right;
            switch (*(t->op)) {
                // Arithmetic
                case '+': return evaluate(left) + evaluate(right); break; // Addition
                case '-': return evaluate(left) - evaluate(right); break; // Subtraction
                case '*': return evaluate(left) * evaluate(right); break; // Multiplication
                case '/': return evaluate(left) / evaluate(right); break; // Division
                case '%': return evaluate(left) % evaluate(right); break; // Modulus
                case '^': return pow(evaluate(left), evaluate(right)); break; // Power
                case '?': return (evaluate(left) == 1) ? evaluate(middle) : evaluate(right); break; // Ternary
                case '>': return evaluate(left) > evaluate(right); break; // Greater
                case '<': return evaluate(left) < evaluate(right); break; // Less
                case 'e': return evaluate(left) == evaluate(right); break; // Equal
                case 'n': return evaluate(left) != evaluate(right); break; // Not Equal
                case 'g': return evaluate(left) >= evaluate(right); break; // Greater or Equal 
                case 'l': return evaluate(left) <= evaluate(right); break; // Less or Equal
                // Variables
                case '=': {
                    int total = evaluate(left, true);
                    int value = evaluate(right, true);
                    if (total == 0) {
                        const char* ident = left->id;
                        var_int_map[id] = std::string(ident);
                        var_str_map[ident] = id;
                        var_map[id] = value;
                        id++;
                    } else {
                        if (is_func_map[total] == true) { yyerror("Function pointer cant be altered."); }
                        else { var_map[total] = value; }
                    }
                    return 0;
                    break;
                }
                // Functions
                case 'f': {
                    int total = evaluate(left, true);
                    if (total == 0) {
                        const char* ident = left->id;
                        var_int_map[id] = std::string(ident);
                        var_str_map[ident] = id;
                        var_map[id] = id;
                        is_func_map[id] = true;
                        if (strcmp(middle->id, ident) == 0) {
                            // Otherwise, the ID will be returned rather than the function being ran.
                            yyerror("Function name and parameter name cannot be the same."); 
                        }
                        struct function f;
                        f.parameters.push_back(middle != NULL ? middle->id : " ");
                        f.nodes = right;
                        var_func_map[id] = f;
                        id++;
                    } else {
                        yyerror("Function was redefined.");
                    }
                    return 0;
                    break;
                }
                case 'c': {
                    const std::map<int, int> var_map_copy(var_map); // Does not cause the slow.
                    struct function localcopy = var_func_map[var_str_map[left->id]];
                    if (right != NULL) {
                        // Currently this will only work for one paramter
                        if (localcopy.parameters.front() == " ") {
                            char *string = (char*)malloc(50);
                            snprintf(string, 50, "Argument Overflow. Expected %d.", 1);
                            yyerror(string);
                            free(string);
                        } else {
                            var_map[var_str_map[localcopy.parameters.front()]] = evaluate(right); 
                        }
                    }
                    int c = evaluate(localcopy.nodes);
                    var_map = var_map_copy;
                    return c;
                    // break;
                }
            }
        }
        return 0;
    }
    // =================================
    // struct Range {int min; int max;};
    // 2 > (1, 2]
    // =================================
    // https://stackoverflow.com/questions/6636808/repl-for-interpreter-using-flex-bison
%}

%union { int num; char* id; struct node* node; /* struct StringVector* str_vector; */ }
%start line
%token EQU
%token NEQ
%token LET
%token GET
%token <id> print
%token <id> Identifier
%token <num> Number
%type <num> term
%type <node> ident
%type <node> assignment
%type <node> exp
// %type <str_vector> params

%left '+' '-'
%left '*' '/' '%'
%left '<' '>'
%left EQU NEQ LET GET
%left '^'

%%

line : 
    | exp ';'                       {/* printf("[Unused] \033[0;33m%d\033[0m\n", evaluate($1)); */ ;}
    | assignment ';'                {evaluate($1);}
    | print exp ';'                 {printf("\033[0;33m%d\033[0m\n", evaluate($2));}
    | line exp ';'                  {/* printf("[Unused] \033[0;33m%d\033[0m\n", evaluate($2)); */ ;}
    | line assignment ';'           {evaluate($2);}
    | line print exp ';'            {printf("\033[0;33m%d\033[0m\n", evaluate($3));}
    ;

ident: Identifier { $$ = makeLeafNodeIdentifier($1); }

// params: Identifier { $$ = create_string_vector($1); }
//     | params ',' Identifier { $$ = extend_string_vector($1, $3); }

assignment : ident '=' exp { $$ = makeOperatorNode('=', $1, $3); }
    | ident '(' ')' '=' exp { $$ = makeOperatorNode('f', $1, $5); }
    | ident '(' ident ')' '=' exp { $$ = makeOperatorNodeAdvanced('f', $1, $3, $6); }
    // | ident '(' params ')' '=' exp { $$ = makeOperatorNode('f', $1, $3, $6); }
    ;

exp : ident { $$ = $1; }
    | term { $$ = makeLeafNode($1); }
    | exp '+' exp { $$ = makeOperatorNode('+', $1, $3); }
    | exp '-' exp { $$ = makeOperatorNode('-', $1, $3); }
    | exp '*' exp { $$ = makeOperatorNode('*', $1, $3); }
    | exp '/' exp { $$ = makeOperatorNode('/', $1, $3); }
    | exp '%' exp { $$ = makeOperatorNode('%', $1, $3); }
    | exp '<' exp { $$ = makeOperatorNode('<', $1, $3); }
    | exp '>' exp { $$ = makeOperatorNode('>', $1, $3); }
    | exp '^' exp { $$ = makeOperatorNode('^', $1, $3); }
    | exp EQU exp { $$ = makeOperatorNode('e', $1, $3); }
    | exp NEQ exp { $$ = makeOperatorNode('n', $1, $3); }
    | exp LET exp { $$ = makeOperatorNode('l', $1, $3); }
    | exp GET exp { $$ = makeOperatorNode('g', $1, $3); }
    | ident '(' ')' { $$ = makeOperatorNode('c', $1, NULL); }
    | ident '(' exp ')' { $$ = makeOperatorNode('c', $1, $3); }
    | exp '?' exp ':' exp { $$ = makeOperatorNodeAdvanced('?', $1, $3, $5); }
    | '(' exp ')' { $$ = $2; }
    // | '|' exp '|' { $$ = abs($2); }
    ;

term : Number { $$ = $1; }
    | '-' Number { $$ = $2 * -1; }
    ;
%%

int main(int argc, char **argv) {
    // printf("loq %s (%s, %s, %s) [%s]\n", "0.0.1", "dev", __DATE__, __TIME__, __VERSION__);
    yyparse();
    return 0;
}