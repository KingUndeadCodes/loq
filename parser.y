// Complete this file... Add functions
%{
    #include <map>
    #include <list>
    #include <vector>
    #include <string>
    #include <algorithm>
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
    int function_depth = 0;
    int max_function_depth = 0;
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
                        /*
                        if (middle != NULL) {
                            if (strcmp(middle->id, ident) == 0) {
                                // Otherwise, the ID will be returned rather than the function being ran.
                                yyerror("Function name and parameter name cannot be the same."); 
                            }
                        }
                        */
                        struct function f;
                        if (middle != NULL) {
                            if (*(middle->op) == 'p') {
                                for (struct node* temp = middle; temp != NULL; temp = temp->left) f.parameters.push_back(temp->middle->id);
                            }
                        } else { f.parameters.push_back(" "); }
                        // printf("%s", "Hello, World!\n");
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
                    // NOTE: Parametrs need to pre-reserved.
                    // Recurssion is not supported for multiple parameters.
                    const std::map<int, int> var_map_copy(var_map); // Does not cause the slow.
                    const std::unordered_map<int, std::string> var_int_map_copy(var_int_map);
                    const std::unordered_map<std::string, int> var_str_map_copy(var_str_map);
                    const int duplicateID = id;
                    struct function localcopy = var_func_map[var_str_map[left->id]];
                    if (right != NULL) { // && *(right->op) == 'v'
                        std::vector<std::string> parameters = localcopy.parameters;
                        const int parameter_count = parameters.size();
                        std::reverse(parameters.begin(), parameters.end());
                        int value_count = 0;
                        // printf("%s", right->op);
                        for (struct node* temp = right; temp != NULL; temp = temp->left) value_count++;
                        // printf("%d\n", value_count);
                        if (value_count > parameter_count) {
                            char *string = (char*)malloc(50);
                            snprintf(string, 50, "Argument Overflow. Expected %d, Got %d.", parameter_count, value_count);
                            yyerror(string);
                            free(string);
                        } else if (value_count < parameter_count) {
                            char *string = (char*)malloc(50);
                            snprintf(string, 50, "Argument Underflow. Expected %d, Got %d.", parameter_count, value_count);
                            yyerror(string);
                            free(string);
                        } else {                            
                            int count = value_count - 1;
                            std::list<int> list = std::list<int>();
                            for (struct node* temp = right; temp != NULL; temp = temp->left) {
                                list.push_back(evaluate(temp->middle));
                            }
                            for (struct node* temp = right; temp != NULL; temp = temp->left) { 
                                int _value = list.front();
                                list.pop_front();
                                const std::string ident = parameters[count--];
                                // if (temp->middle->id != NULL) {
                                //     std::string s = temp->middle->id; 
                                //     if (std::find(parameters.begin(), parameters.end(), s) != parameters.end()) {
                                //         printf("%s", "Hello!");
                                //         _value = var_map[var_str_map[temp->middle->id]];
                                //     }
                                // }
                                //
                                if (var_str_map[ident] == 0) {
                                    // printf("%s = %d\n", ident.c_str(), _value);
                                    var_int_map[id] = ident;
                                    var_str_map[ident] = id;
                                    var_map[id] = _value;
                                    id++;
                                } else {
                                    var_map[var_str_map[ident]] = _value;
                                }
                                // if (temp->middle->id != NULL) {
                                //     printf("%s at %d is %d (variable)\n", ident.c_str(), var_str_map[ident], var_map[var_str_map[temp->middle->id]]);
                                // } else {
                                //     printf("%s at %d is %d\n", ident.c_str(), var_str_map[ident], _value);
                                // }
                            }
                        }
                    }
                    int c = evaluate(localcopy.nodes);           
                    id = duplicateID;
                    var_map = var_map_copy;
                    var_int_map = var_int_map_copy;
                    var_str_map = var_str_map_copy;
                    return c;
                }
            }
        }
        return 0;
    }
    struct ParameterVector { std::vector<struct node> nodes; };
    struct ValueVector { std::vector<struct node> values; };
    struct ValueVector* CreateValueVector(void) {
        struct ValueVector *temp;
        temp = (struct ValueVector*)malloc(sizeof(struct ValueVector));
        return temp;
    }
    struct ValueVector* AddValueVector(struct ValueVector* Vector, struct node* value) {
        Vector->values.push_back(*value);
        return Vector;
    }
    struct node* ConvertValueVectorToNode(struct ValueVector* Vector) {
        struct node* head = NULL;
        // for (auto & itr : Vector->values) {
        for(std::vector<struct node>::iterator it = Vector->values.begin(); it != Vector->values.end(); ++it) {
            struct node itr = *it;
            // printf(">>> %d\n", itr.value);
            if (itr.op == NULL) {
                if (itr.id != NULL) {
                    if (head == NULL) {
                        struct node* temp = (struct node*)malloc(sizeof(struct node));
                        temp->op = (char*)malloc(sizeof(char) * 2);
                        temp->left = NULL;
                        temp->middle = makeLeafNodeIdentifier(itr.id);
                        temp->right = NULL;
                        temp->id = NULL;
                        strcpy(temp->op, "v"); // *(temp->op) = 'v';    
                        head = temp;
                        // IDEA! Use `head->value` for a default value.
                    } else {
                        struct node* temp = (struct node*)malloc(sizeof(struct node));
                        temp->op = (char*)malloc(sizeof(char) * 2);
                        temp->left = head;
                        temp->middle = makeLeafNodeIdentifier(itr.id);
                        temp->right = NULL;
                        temp->id = NULL;
                        strcpy(temp->op, "v"); // *(temp->op) = 'v';    
                        head->right = temp;
                        head = temp;
                    }
                    // printf("Hold up: %s\n", itr.id);
                } else {
                    if (head == NULL) {
                        struct node* temp = (struct node*)malloc(sizeof(struct node));
                        temp->op = (char*)malloc(sizeof(char) * 2);
                        temp->left = NULL;
                        temp->middle = makeLeafNode(itr.value);
                        temp->right = NULL;
                        temp->id = NULL;
                        strcpy(temp->op, "v"); // *(temp->op) = 'v';    
                        head = temp;
                        // IDEA! Use `head->value` for a default value.
                    } else {
                        struct node* temp = (struct node*)malloc(sizeof(struct node));
                        temp->op = (char*)malloc(sizeof(char) * 2);
                        temp->left = head;
                        temp->middle = makeLeafNode(itr.value);
                        temp->right = NULL;
                        temp->id = NULL;
                        strcpy(temp->op, "v"); // *(temp->op) = 'v';    
                        head->right = temp;
                        head = temp;
                    }
                }
            } else {
                if (itr.value == 0) {
                    // Evaluate itr and sets its value to the result.
                    itr.value = evaluate(&itr);
                }
                // printf("%c", *(itr.op));
                if (head == NULL) {
                    struct node* temp = (struct node*)malloc(sizeof(struct node));
                    temp->op = (char*)malloc(sizeof(char) * 2);
                    temp->left = NULL;
                    temp->middle = makeOperatorNodeAdvanced(*(itr.op), itr.left, itr.middle, itr.right); // *(itr.op) is the issue here.
                    temp->right = NULL;
                    temp->id = NULL;
                    strcpy(temp->op, "v"); // *(temp->op) = 'v';    
                    head = temp;
                    // IDEA! Use `head->value` for a default value.
                } else {
                    struct node* temp = (struct node*)malloc(sizeof(struct node));
                    temp->op = (char*)malloc(sizeof(char) * 2);
                    temp->left = head;
                    temp->middle = makeOperatorNodeAdvanced(*(itr.op), itr.left, itr.middle, itr.right);
                    temp->right = NULL;
                    temp->id = NULL;
                    strcpy(temp->op, "v"); // *(temp->op) = 'v';    
                    head->right = temp;
                    head = temp;
                }
            }
        };
        // for (struct node* temp = head; temp != NULL; temp = temp->left) {
        //     printf("%d\n", temp->middle->value);
        // }
        return head;
    }
    struct ParameterVector* CreateParameterVector(void) {
        struct ParameterVector *temp;
        temp = (struct ParameterVector*)malloc(sizeof(struct ParameterVector));
        return temp;
    }
    struct ParameterVector* AddParameterVector(struct ParameterVector* Vector, struct node* node) {
        Vector->nodes.push_back(*node);
        return Vector;
    }
    struct node* ConvertParameterVectorToNode(struct ParameterVector* Vector) {
        struct node* head = NULL;
        // for (auto itr : Vector->nodes) {
        for(std::vector<struct node>::iterator it = Vector->nodes.begin(); it != Vector->nodes.end(); ++it) {
            const struct node itr = *it;
            if (head == NULL) {
                struct node* temp = (struct node*)malloc(sizeof(struct node));
                temp->op = (char*)malloc(sizeof(char) * 2); // This might be a problem.
                temp->left = NULL;
                temp->middle = makeLeafNodeIdentifier(itr.id);
                temp->right = NULL;
                temp->id = NULL;
                strcpy(temp->op, "p"); // *(temp->op) = 'p';
                head = temp;
                // IDEA! Use `head->value` for a default value.
            } else {
                struct node* temp = (struct node*)malloc(sizeof(struct node));
                temp->op = (char*)malloc(sizeof(char) * 2); // This might be a problem.
                temp->left = head;
                temp->middle = makeLeafNodeIdentifier(itr.id);
                temp->right = NULL;
                temp->id = NULL;
                strcpy(temp->op, "p"); // *(temp->op) = 'p';
                head->right = temp;
                head = temp;
            }
            // printf("%s\n", itr.id);
            // printf("%s\n", head->middle->id);
        };
        /*
        for (struct node* temp = head; temp != NULL; temp = temp->left) {
            printf("%s\n", (const char*)temp->middle->id);
        }
        */
        return head;
    }
    // =================================
    // struct Range {int min; int max;};
    // 2 > (1, 2]
    // =================================
    // https://stackoverflow.com/questions/6636808/repl-for-interpreter-using-flex-bison
%}

%union { int num; char* id; struct node* node; struct ParameterVector* str_vector; struct ValueVector* value_vector; }
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
%type <str_vector> params
%type <value_vector> values

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

params : ident { 
        struct ParameterVector* String = CreateParameterVector();
        AddParameterVector(String, $1);
        $$ = String;
    }
    | params ',' ident {
        struct ParameterVector* String = $1; 
        AddParameterVector(String, $3);
        $$ = String;
    }

values : exp {
        struct ValueVector* Value = CreateValueVector();
        AddValueVector(Value, $1); // Using `evaluate` is kind of nasty work-around.
        $$ = Value;
    }
    | values ',' exp {
        struct ValueVector* Value = $1; 
        AddValueVector(Value, $3); // // Using `evaluate` is kind of nasty work-around.
        $$ = Value;
    }

assignment : ident '=' exp { $$ = makeOperatorNode('=', $1, $3); }
    | ident '(' ')' '=' exp { $$ = makeOperatorNodeAdvanced('f', $1, NULL, $5); }
    // | ident '(' ident ')' '=' exp { $$ = makeOperatorNodeAdvanced('f', $1, $3, $6); }
    | ident '(' params ')' '=' exp { $$ = makeOperatorNodeAdvanced('f', $1, ConvertParameterVectorToNode($3), $6); /* (void)ConvertParameterVectorToNode($3); */ }
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
    // | ident '(' exp ')' { $$ = makeOperatorNode('c', $1, $3); }
    | ident '(' values ')' { $$ = makeOperatorNode('c', $1, ConvertValueVectorToNode($3)); }
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