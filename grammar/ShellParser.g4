// shell parser grammar. Powered by https://github.com/antlr/antlr4
// Use ./generate-shell-parser.sh to regenerate grammar code
parser grammar ShellParser;

options {
    tokenVocab = './grammar/ShellLexer';
}

root : NL* (cmds EOF | EOF) ; // Consume ALL the input

cmds
    : IF cmd THEN cmds? (ELIF cmd THEN cmds?)* (ELSE cmds?)? END  #IfElse
    | cmd (SEMICOLON | NL)+ (cmds)*?                              #Seq
    | cmd                                                         #Seq
    ;

cmd
    : WORD arg*                                                              #Args
    | cmd NL* PIPE cmd                                                       #Pipe
    | cmd NL* AND cmd                                                        #And
    | cmd NL* OR cmd                                                         #Or
    | LPAR cmds RPAR                                                         #Parens
    | LPAR cmds RPAR RPAR  {notifyErrorListeners("Unbalanced parenthesis")}  #CmdError
    | LPAR cmds            {notifyErrorListeners("Unbalanced parenthesis")}  #CmdError
    ;

arg
    : ARG                                #Word
    | WORD                               #Word
    | SINGLE_QUOTED_STRING               #SQuotedString
    | LDQUOTE dStringFragment* RDQUOTE   #DQuotedString
    | INTERPOLATION_START cmds RPAR      #Substitution

    | LDQUOTE dStringFragment* RDQUOTE RDQUOTE {notifyErrorListeners("Unbalanced quotes")}  #ArgError
    | LDQUOTE dStringFragment*                 {notifyErrorListeners("Unbalanced quotes")}  #ArgError
    | INTERPOLATION_START cmds RPAR RPAR {notifyErrorListeners("Unbalanced parenthesis")}   #ArgError
    | INTERPOLATION_START cmds           {notifyErrorListeners("Unbalanced parenthesis")}   #ArgError
    ;

dStringFragment
    : TEXT                                                                                            #Text
    | ESCAPE_SEQUENCE                                                                                 #EscapeSequence
    | INTERPOLATION_START_IN_DSTRING cmds RPAR                                                        #Interpolation
    | INTERPOLATION_START_IN_DSTRING cmds RPAR RPAR {notifyErrorListeners("Unbalanced parenthesis")}  #DStringFragmentError
    | INTERPOLATION_START_IN_DSTRING cmds           {notifyErrorListeners("Unbalanced parenthesis")}  #DStringFragmentError
    ;
