// Generated from ./grammar/AeroShellLexer.g4 by ANTLR 4.13.1
import Antlr4

open class AeroShellLexer: Lexer {

	internal static var _decisionToDFA: [DFA] = {
          var decisionToDFA = [DFA]()
          let length = AeroShellLexer._ATN.getNumberOfDecisions()
          for i in 0..<length {
          	    decisionToDFA.append(DFA(AeroShellLexer._ATN.getDecisionState(i)!, i))
          }
           return decisionToDFA
     }()

	internal static let _sharedContextCache = PredictionContextCache()

	public
	static let RESERVED=1, SINGLE_QUOTED_STRING=2, LDQUOTE=3, LPAR=4, INTERPOLATION_START=5, 
            RPAR=6, WORD=7, AND=8, PIPE=9, OR=10, NOT=11, SEMICOLON=12, 
            NEWLINES=13, ESCAPE_NEWLINE=14, COMMENT=15, SPACES=16, TEXT=17, 
            INTERPOLATION_START_IN_DSTRING=18, ESCAPE_SEQUENCE=19, RDQUOTE=20

	public
	static let IN_DSTRING=1
	public
	static let channelNames: [String] = [
		"DEFAULT_TOKEN_CHANNEL", "HIDDEN"
	]

	public
	static let modeNames: [String] = [
		"DEFAULT_MODE", "IN_DSTRING"
	]

	public
	static let ruleNames: [String] = [
		"RESERVED", "SINGLE_QUOTED_STRING", "LDQUOTE", "LPAR", "INTERPOLATION_START", 
		"RPAR", "WORD", "AND", "PIPE", "OR", "NOT", "SEMICOLON", "NEWLINES", "ESCAPE_NEWLINE", 
		"COMMENT", "SPACES", "TEXT", "INTERPOLATION_START_IN_DSTRING", "ESCAPE_SEQUENCE", 
		"RDQUOTE"
	]

	private static let _LITERAL_NAMES: [String?] = [
		nil, nil, nil, nil, "'('", nil, "')'", nil, "'&&'", "'|'", "'||'", nil, 
		"';'"
	]
	private static let _SYMBOLIC_NAMES: [String?] = [
		nil, "RESERVED", "SINGLE_QUOTED_STRING", "LDQUOTE", "LPAR", "INTERPOLATION_START", 
		"RPAR", "WORD", "AND", "PIPE", "OR", "NOT", "SEMICOLON", "NEWLINES", "ESCAPE_NEWLINE", 
		"COMMENT", "SPACES", "TEXT", "INTERPOLATION_START_IN_DSTRING", "ESCAPE_SEQUENCE", 
		"RDQUOTE"
	]
	public
	static let VOCABULARY = Vocabulary(_LITERAL_NAMES, _SYMBOLIC_NAMES)


	override open
	func getVocabulary() -> Vocabulary {
		return AeroShellLexer.VOCABULARY
	}

	public
	required init(_ input: CharStream) {
	    RuntimeMetaData.checkVersion("4.13.1", RuntimeMetaData.VERSION)
		super.init(input)
		_interp = LexerATNSimulator(self, AeroShellLexer._ATN, AeroShellLexer._decisionToDFA, AeroShellLexer._sharedContextCache)
	}

	override open
	func getGrammarFileName() -> String { return "AeroShellLexer.g4" }

	override open
	func getRuleNames() -> [String] { return AeroShellLexer.ruleNames }

	override open
	func getSerializedATN() -> [Int] { return AeroShellLexer._serializedATN }

	override open
	func getChannelNames() -> [String] { return AeroShellLexer.channelNames }

	override open
	func getModeNames() -> [String] { return AeroShellLexer.modeNames }

	override open
	func getATN() -> ATN { return AeroShellLexer._ATN }

	static let _serializedATN:[Int] = [
		4,0,20,146,6,-1,6,-1,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,2,4,7,4,2,5,7,5,2,
		6,7,6,2,7,7,7,2,8,7,8,2,9,7,9,2,10,7,10,2,11,7,11,2,12,7,12,2,13,7,13,
		2,14,7,14,2,15,7,15,2,16,7,16,2,17,7,17,2,18,7,18,2,19,7,19,1,0,1,0,1,
		0,1,0,1,0,1,0,3,0,49,8,0,1,1,1,1,5,1,53,8,1,10,1,12,1,56,9,1,1,1,1,1,1,
		2,1,2,1,2,1,2,1,3,1,3,1,3,1,3,1,4,1,4,1,4,1,4,1,4,1,5,1,5,1,5,1,5,1,6,
		4,6,78,8,6,11,6,12,6,79,1,7,1,7,1,7,1,8,1,8,1,9,1,9,1,9,1,10,1,10,1,10,
		1,11,1,11,1,12,1,12,1,12,5,12,98,8,12,10,12,12,12,101,9,12,1,13,1,13,3,
		13,105,8,13,1,13,3,13,108,8,13,1,13,1,13,1,13,1,13,1,14,1,14,5,14,116,
		8,14,10,14,12,14,119,9,14,1,14,1,14,1,15,4,15,124,8,15,11,15,12,15,125,
		1,15,1,15,1,16,4,16,131,8,16,11,16,12,16,132,1,17,1,17,1,17,1,17,1,17,
		1,18,1,18,1,18,1,19,1,19,1,19,1,19,1,54,0,20,2,1,4,2,6,3,8,4,10,5,12,6,
		14,7,16,8,18,9,20,10,22,11,24,12,26,13,28,14,30,15,32,16,34,17,36,18,38,
		19,40,20,2,0,1,4,7,0,37,37,43,57,61,61,64,91,93,95,97,123,125,125,1,0,
		10,10,2,0,9,9,32,32,3,0,34,34,36,36,92,92,154,0,2,1,0,0,0,0,4,1,0,0,0,
		0,6,1,0,0,0,0,8,1,0,0,0,0,10,1,0,0,0,0,12,1,0,0,0,0,14,1,0,0,0,0,16,1,
		0,0,0,0,18,1,0,0,0,0,20,1,0,0,0,0,22,1,0,0,0,0,24,1,0,0,0,0,26,1,0,0,0,
		0,28,1,0,0,0,0,30,1,0,0,0,0,32,1,0,0,0,1,34,1,0,0,0,1,36,1,0,0,0,1,38,
		1,0,0,0,1,40,1,0,0,0,2,48,1,0,0,0,4,50,1,0,0,0,6,59,1,0,0,0,8,63,1,0,0,
		0,10,67,1,0,0,0,12,72,1,0,0,0,14,77,1,0,0,0,16,81,1,0,0,0,18,84,1,0,0,
		0,20,86,1,0,0,0,22,89,1,0,0,0,24,92,1,0,0,0,26,94,1,0,0,0,28,102,1,0,0,
		0,30,113,1,0,0,0,32,123,1,0,0,0,34,130,1,0,0,0,36,134,1,0,0,0,38,139,1,
		0,0,0,40,142,1,0,0,0,42,43,5,34,0,0,43,44,5,34,0,0,44,49,5,34,0,0,45,46,
		5,39,0,0,46,47,5,39,0,0,47,49,5,39,0,0,48,42,1,0,0,0,48,45,1,0,0,0,49,
		3,1,0,0,0,50,54,5,39,0,0,51,53,9,0,0,0,52,51,1,0,0,0,53,56,1,0,0,0,54,
		55,1,0,0,0,54,52,1,0,0,0,55,57,1,0,0,0,56,54,1,0,0,0,57,58,5,39,0,0,58,
		5,1,0,0,0,59,60,5,34,0,0,60,61,1,0,0,0,61,62,6,2,0,0,62,7,1,0,0,0,63,64,
		5,40,0,0,64,65,1,0,0,0,65,66,6,3,1,0,66,9,1,0,0,0,67,68,5,36,0,0,68,69,
		5,40,0,0,69,70,1,0,0,0,70,71,6,4,1,0,71,11,1,0,0,0,72,73,5,41,0,0,73,74,
		1,0,0,0,74,75,6,5,2,0,75,13,1,0,0,0,76,78,7,0,0,0,77,76,1,0,0,0,78,79,
		1,0,0,0,79,77,1,0,0,0,79,80,1,0,0,0,80,15,1,0,0,0,81,82,5,38,0,0,82,83,
		5,38,0,0,83,17,1,0,0,0,84,85,5,124,0,0,85,19,1,0,0,0,86,87,5,124,0,0,87,
		88,5,124,0,0,88,21,1,0,0,0,89,90,5,33,0,0,90,91,3,32,15,0,91,23,1,0,0,
		0,92,93,5,59,0,0,93,25,1,0,0,0,94,99,5,10,0,0,95,98,3,32,15,0,96,98,5,
		10,0,0,97,95,1,0,0,0,97,96,1,0,0,0,98,101,1,0,0,0,99,97,1,0,0,0,99,100,
		1,0,0,0,100,27,1,0,0,0,101,99,1,0,0,0,102,104,5,92,0,0,103,105,3,32,15,
		0,104,103,1,0,0,0,104,105,1,0,0,0,105,107,1,0,0,0,106,108,3,30,14,0,107,
		106,1,0,0,0,107,108,1,0,0,0,108,109,1,0,0,0,109,110,5,10,0,0,110,111,1,
		0,0,0,111,112,6,13,3,0,112,29,1,0,0,0,113,117,5,35,0,0,114,116,8,1,0,0,
		115,114,1,0,0,0,116,119,1,0,0,0,117,115,1,0,0,0,117,118,1,0,0,0,118,120,
		1,0,0,0,119,117,1,0,0,0,120,121,6,14,3,0,121,31,1,0,0,0,122,124,7,2,0,
		0,123,122,1,0,0,0,124,125,1,0,0,0,125,123,1,0,0,0,125,126,1,0,0,0,126,
		127,1,0,0,0,127,128,6,15,3,0,128,33,1,0,0,0,129,131,8,3,0,0,130,129,1,
		0,0,0,131,132,1,0,0,0,132,130,1,0,0,0,132,133,1,0,0,0,133,35,1,0,0,0,134,
		135,5,36,0,0,135,136,5,40,0,0,136,137,1,0,0,0,137,138,6,17,1,0,138,37,
		1,0,0,0,139,140,5,92,0,0,140,141,9,0,0,0,141,39,1,0,0,0,142,143,5,34,0,
		0,143,144,1,0,0,0,144,145,6,19,2,0,145,41,1,0,0,0,13,0,1,48,54,77,79,97,
		99,104,107,117,125,132,4,5,1,0,5,0,0,4,0,0,6,0,0
	]

	public
	static let _ATN: ATN = try! ATNDeserializer().deserialize(_serializedATN)
}