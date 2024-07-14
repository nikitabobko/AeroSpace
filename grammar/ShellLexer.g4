// AeroShell lexer grammar. Powered by https://github.com/antlr/antlr4
// Use ./generate-aero-shell-parser.sh to regenerate grammar code
lexer grammar AeroShellLexer;

RESERVED : '"""' | '\'\'\'' ;

SINGLE_QUOTED_STRING : '\'' .*? '\'' ;

LDQUOTE : '"' -> pushMode(IN_DSTRING) ;
LPAR : '(' -> pushMode(DEFAULT_MODE) ;
INTERPOLATION_START : '$(' -> pushMode(DEFAULT_MODE) ;
RPAR : ')' -> popMode ;

WORD : ([a-zA-Z0-9] | '.' | '_' | '-' | '+' | '/' | '%' | '{' | '}' | '@' | ',' | '[' | ']' | '=' | '^')+ ;
AND : '&&' ;
PIPE : '|' ;
OR : '||' ;
NOT : '!' SPACES ; // require space to make it possible use bang in arguments (not used yet, and maybe it's worth to allow '!false')
SEMICOLON : ';' ;
NEWLINES : '\n' (SPACES | '\n')* ;

ESCAPE_NEWLINE : '\\' SPACES? COMMENT? '\n' -> skip ;
COMMENT : '#' ~('\n')* -> skip ;
SPACES : [ \t]+ -> skip ;

mode IN_DSTRING;
TEXT : ~('\\' | '"' | '$')+ ;
INTERPOLATION_START_IN_DSTRING : '$(' -> pushMode(DEFAULT_MODE) ;
ESCAPE_SEQUENCE : '\\' . ;
RDQUOTE : '"' -> popMode ;
