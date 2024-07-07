// AeroShell parser grammar. Powered by https://github.com/antlr/antlr4
// Use ./generate-aero-shell-parser.sh to regenerate grammar code
parser grammar AeroShellParser;

options {
    tokenVocab = './grammar/AeroShellLexer';
}

root : program EOF | EOF ; // Consume ALL the input

program
    : NOT program                                    #Not
    | program NEWLINES? PIPE program                 #Pipe
    | program NEWLINES? AND program                  #And
    | program NEWLINES? OR program                   #Or
    | program (SEMICOLON | NEWLINES) (program)*?     #Seq
    | LPAR program RPAR                              #Parens
    | arg+                                           #Args
    ;

arg
    : WORD                                  #Word
    | LDQUOTE dStringFragment* RDQUOTE      #DQuotedString
    | INTERPOLATION_START program RPAR      #Substitution
    | SINGLE_QUOTED_STRING                  #SQuotedString
    ;

dStringFragment
    : TEXT                                          #Text
    | ESCAPE_SEQUENCE                               #EscapeSequence
    | INTERPOLATION_START_IN_DSTRING program RPAR   #Interpolation
    ;
