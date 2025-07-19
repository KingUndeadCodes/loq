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
    #include <stack>
    #include "loqlib.h"
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
    // int function_depth = 0;
    // int max_function_depth = 0;
    enum node_value_type {
        /* NODE_VALUE_TYPE_INT = 0, */
        NODE_VALUE_TYPE_FLOAT = 0, // unused
        NODE_VALUE_TYPE_STRING = 1,
        // NODE_VALUE_TYPE_ARRAY = 2, // unused
    };
    struct value_box {
        enum node_value_type type;
        union {
            float value_float;  // Used for floating point numbers (unused)
            char* value_string; // Used for string values
            // void* array;     // Used for arrays (unused)
        };
        bool claimed;
    };
    struct node {
        bool reference;
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
    int stack_id = 0;
    /* static std::map<int, std::vector<std::string> > func_map; */
    static std::map<int, int> var_map;
    static std::unordered_map<int, bool> is_func_map;
    static std::unordered_map<int, std::string> var_int_map; // Just to hold the name
    static std::unordered_map<std::string, int> var_str_map; // Reverse of `var_int_map`
    static std::unordered_map<int, struct function> var_func_map;
    static std::unordered_map<int, struct value_box> values_stack;
    static std::stack<int> stack_id_available;
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
    struct node* makeLeafNode(const char* str) {
        struct node* temp;
        struct value_box value = {
            .type = NODE_VALUE_TYPE_STRING,
            .value_string = NULL,
            .claimed = false,
        };
        value.value_string = (char*)malloc(strlen(str) * sizeof(char));
        strcpy(value.value_string, str);
        values_stack[stack_id] = value;
        temp = (struct node*)malloc(sizeof(struct node));
        temp->op = NULL;
        temp->reference = true;
        temp->value = stack_id++;
        temp->left = NULL;
        temp->middle = NULL;
        temp->right = NULL;
        temp->id = NULL;
        return temp;
    };
    void freeNode(struct node* n) {
        if (n != NULL) return;
        if (n->reference == true) {
            if (values_stack[stack_id].claimed == false) {
                if (values_stack[stack_id].type == NODE_VALUE_TYPE_STRING) {
                    free(values_stack[stack_id].value_string);
                }
            } 
        }
        if (n->op != NULL) free(n->op);
        if (n->left != NULL) freeNode(n->left);
        if (n->middle != NULL) freeNode(n->middle);
        if (n->right != NULL) freeNode(n->right);
        free(n);
    }
    uint8_t isReferenceNode(struct node* l, struct node* m, struct node* r) {
        // This function returns a 3 bit value.
        // If the most significant bit is set, then the left node is a reference node.
        // If the second most significant bit is set, then the middle node is a reference node.
        // If the least significant bit is set, then the right node is a reference node.
        uint8_t result = 0;
        if (l != NULL && l->reference == true) result |= 0b100;
        if (m != NULL && m->reference == true) result |= 0b010;
        if (r != NULL && r->reference == true) result |= 0b001;
        return result;
    };
    int fetchNextAvailableStackID() {
        if (stack_id_available.empty()) {
            stack_id++;
            return (stack_id) - 1;
        }
        int stack_id_dup = stack_id_available.top();
        stack_id_available.pop();
        return stack_id_dup;
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
            uint8_t references = isReferenceNode(left, middle, right);
            if (references != 0) {
                switch(*(t->op)) {
                    case '+': {
                        if (references == 0b101) {
                            // Compare Types
                            enum node_value_type typeLeft = values_stack[left->value].type;
                            enum node_value_type typeRight = values_stack[right->value].type;
                            if ((typeLeft == NODE_VALUE_TYPE_STRING) && (typeLeft == typeRight)) {
                                // If left or right is unclaimed, it would be preferable to claim either one of them rather than creating a new string. 
                                bool leftClaimed = values_stack[left->value].claimed;
                                bool rightClaimed = values_stack[right->value].claimed;
                                if (leftClaimed == false) {
                                    values_stack[left->value].value_string = safe_strcat(values_stack[left->value].value_string, values_stack[right->value].value_string);
                                    if (rightClaimed == false) stack_id_available.push(right->value);
                                    return left->value;
                                } else if (rightClaimed == false) {
                                    values_stack[right->value].value_string = safe_strcat(values_stack[right->value].value_string, values_stack[left->value].value_string);
                                    return right->value;
                                } else {
                                    struct value_box newValue;
                                    newValue.type = NODE_VALUE_TYPE_STRING;
                                    newValue.value_string = safe_strcat(values_stack[left->value].value_string, values_stack[right->value].value_string);
                                    newValue.claimed = false;
                                    int new_id = fetchNextAvailableStackID();
                                    values_stack[new_id] = newValue;
                                    return new_id; // Return the ID of the new value.
                                } 
                            }
                        } else {
                            // This error will occur when my terrible fix is removed.
                            yyerror("Error 2");
                        }
                        break;
                    }
                    case '*': {
                        yyerror("Manipulation of reference nodes via multiplication currently not allowed.");
                        break;
                    }
                    default: {
                        break;
                    }
                }
            }
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
                    const std::map<int, int> var_map_copy(var_map); // Does not cause the slow.
                    const std::unordered_map<int, std::string> var_int_map_copy(var_int_map);
                    const std::unordered_map<std::string, int> var_str_map_copy(var_str_map);
                    const int duplicateID = id;
                    const struct function localcopy = var_func_map[var_str_map[left->id]];
                    if (right != NULL) { // && *(right->op) == 'v'
                        std::vector<std::string> parameters = localcopy.parameters;
                        const int parameter_count = parameters.size();
                        std::reverse(parameters.begin(), parameters.end()); // Theory: This shouldn't be reversed which is what is making it so slow.
                        int value_count = 0;
                        std::list<int> list = std::list<int>();                            
                        for (struct node* temp = right; temp != NULL; temp = temp->left) {
                            list.push_back(evaluate(temp->middle));
                            value_count++;
                        }
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
                            for (int i = value_count; i > 0; i--) { 
                                const std::string ident = parameters[i - 1];
                                if (var_str_map[ident] == 0) {
                                    var_int_map[id] = ident;
                                    var_str_map[ident] = id;
                                    var_map[id] = list.front();
                                    id++;
                                } else {
                                    var_map[var_str_map[ident]] = list.front();
                                }
                                list.pop_front(); // `list.front()` is the value.
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
        for(std::vector<struct node>::iterator it = Vector->values.begin(); it != Vector->values.end(); ++it) {
            struct node itr = *it;
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
                    itr.value = evaluate(&itr);
                }
                if (head == NULL) {
                    struct node* temp = (struct node*)malloc(sizeof(struct node));
                    temp->op = (char*)malloc(sizeof(char) * 2);
                    temp->left = NULL;
                    temp->middle = makeOperatorNodeAdvanced(*(itr.op), itr.left, itr.middle, itr.right); // *(itr.op) is the issue here.
                    temp->right = NULL;
                    temp->id = NULL;
                    strcpy(temp->op, "v"); // *(temp->op) = 'v';    
                    head = temp;
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
                strcpy(temp->op, "p");
                head = temp;
            } else {
                struct node* temp = (struct node*)malloc(sizeof(struct node));
                temp->op = (char*)malloc(sizeof(char) * 2); // This might be a problem.
                temp->left = head;
                temp->middle = makeLeafNodeIdentifier(itr.id);
                temp->right = NULL;
                temp->id = NULL;
                strcpy(temp->op, "p");
                head->right = temp;
                head = temp;
            }
        };
        return head;
    }
    // =================================
    // struct Range {int min; int max;};
    // 2 > (1, 2]
    // =================================
    // https://stackoverflow.com/questions/6636808/repl-for-interpreter-using-flex-bison
    char* strndup(const char* str, struct node* n) {
        int repeat = evaluate(n);
        if (repeat < 0) repeat = 0;
        if (repeat == 0) {
            const char* empty = "";
            return (char*)empty;
        } else {
            size_t len = strlen(str);
            const char* string_copy = strdup(str);
            char *result = (char*)malloc(len * repeat + 1);
            result[0] = '\0';
            for (int i = 0; i < repeat; ++i) strcat(result, string_copy);
            return result;
        }
    };
%}

%union { int num; char* id; char* str; struct node* node; struct ParameterVector* str_vector; struct ValueVector* value_vector; }
%start line
%token EQU
%token NEQ
%token LET
%token GET
%token <id> input
%token <id> print
%token <id> Identifier
%token <num> Number
%token <str> CharacterSequence // String
%type <num> term
%type <node> ident
%type <node> assignment
%type <node> exp
%type <node> string
%type <str_vector> params
%type <value_vector> values
// %type <value_vector> array 

%left '+' '-'
%left '*' '/' '%'
%left '<' '>'
%left EQU NEQ LET GET
%left '^'

%%

line : 
    | exp ';'                       { freeNode($1); } /* printf("[Unused] \033[0;33m%d\033[0m\n", evaluate($1)); */ 
    | assignment ';'                { evaluate($1); freeNode($1); }
    | print exp ';'                 { printf("\033[0;33m%d\033[0m\n", evaluate($2)); freeNode($2); }
    | print string ';'              { printf("%s\n", values_stack[evaluate($2)].value_string); freeNode($2); }
    | line exp ';'                  { freeNode($2); } /* printf("[Unused] \033[0;33m%d\033[0m\n", evaluate($2)); */ 
    | line assignment ';'           { evaluate($2); freeNode($2); }
    | line print exp ';'            { printf("\033[0;33m%d\033[0m\n", evaluate($3)); freeNode($3); }
    | line print string ';'         { printf("%s\n", values_stack[evaluate($3)].value_string); freeNode($3); }
    ;

ident: Identifier { $$ = makeLeafNodeIdentifier($1); }

/*
string: CharacterSequence  { $$ = $1; }
    | '(' string ')'       { $$ = $2; } // Parentheses around string
    | string '+' string    { $$ = strcat($1, $3); } // Concatenate strings
    | string '*' exp       { $$ = strndup($1, $3); } // Repeat string
    | exp '*' string       { $$ = strndup($3, $1); } // Repeat string

// array: '[' values ']' { $$ = $2; }
*/

string: CharacterSequence { $$ = makeLeafNode($1); }
    | '(' string ')' { $$ = $2; } // Parentheses around string
    | string '+' string {
        // TODO: This is a terrible fix.
        // It creates new memory that is not freed.
        // I hate this fix, but it works. How difficult is it to write actually half decent code?
        if (($1->op != NULL && $3->op != NULL) == false) { 
            if ($1->op != NULL) { $1 = makeLeafNode(values_stack[evaluate($1)].value_string); }
            if ($3->op != NULL) { $3 = makeLeafNode(values_stack[evaluate($3)].value_string); }
        }
        $$ = makeOperatorNode('+', $1, $3);
    }

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
    | ident '(' values ')' { $$ = makeOperatorNode('c', $1, ConvertValueVectorToNode($3)); }
    | exp '?' exp ':' exp { $$ = makeOperatorNodeAdvanced('?', $1, $3, $5); }
    | '(' exp ')' { $$ = $2; }
    | input { $$ = makeLeafNode(inputInteger(NULL)); }
    | input string { $$ = makeLeafNode(inputInteger(values_stack[evaluate($2)].value_string)); }
    ;

term : Number { $$ = $1; }
    | '-' Number { $$ = $2 * -1; }
    ;
%%

// instead of loq, what about swing? The name sounds so much better.

int main(int argc, char **argv) {
    // printf("loq %s (%s, %s, %s) [%s]\n", "0.0.1", "dev", __DATE__, __TIME__, __VERSION__);
    // FILE* fp = fopen(argv[2], "a");
    // yyparse(fp);
    yyparse();
    return 0;
}