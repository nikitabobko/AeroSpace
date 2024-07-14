// shell lexer grammar. Powered by https://github.com/antlr/antlr4
// Use ./generate-shell-parser.sh to regenerate grammar code
lexer grammar ShellLexer;

TRIPLE_QUOTE : '"""' | '\'\'\'' ; // Reserved

SINGLE_QUOTED_STRING : '\'' .*? '\'' ;

LDQUOTE : '"' -> pushMode(IN_DSTRING) ;
LPAR : '(' -> pushMode(DEFAULT_MODE) ;
INTERPOLATION_START : '$(' -> pushMode(DEFAULT_MODE) ;
RPAR : ')' {
    _ = Result { try popMode() }
} ;

// Keywords (some of them are unused, just reserved)
ELIF : 'elif' NL* ;
IF : 'if' NL* ;
SWITCH : 'switch' NL* ;
CASE : 'case' NL* ;
DO : 'do' NL* ;
THEN : 'then' NL* ;
ELSE : 'else' NL* ;
FOR : 'for' NL* ;
WHILE : 'while' NL* ;
CATCH : 'catch' NL* ;
IN : 'in' NL* ;
END : 'end' NL* ;
DEFER : 'defer' NL* ;

AND : '&&' ;
PIPE : '|' ;
OR : '||' ;
SEMICOLON : ';' ;
NL : SPACES? ('\r')? '\n' ;
WORD : ([a-zA-Z]    | '.' | '_' | '-' | '/')+ ;
ARG :  ([a-zA-Z0-9] | '.' | '_' | '-' | '/' | '+' | ',' | '=' | '!' | '%' | '{' | '}' | '^')+ ;

ESCAPE_NEWLINE : '\\' SPACES? COMMENT? '\n' -> skip ;
COMMENT : '#' ~('\n')* -> skip ;
SPACES : [ \t]+ -> skip ;

ANY : . ; // Catch all other

mode IN_DSTRING;
TEXT : ~('\\' | '"' | '$')+ ;
INTERPOLATION_START_IN_DSTRING : '$(' -> pushMode(DEFAULT_MODE) ;
ESCAPE_SEQUENCE : '\\' . ;
RDQUOTE : '"' {
    _ = Result { try popMode() }
} ;
