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
		"RESERVED", "SINGLE_QUOTED_STRING", "SINGLE_QUOTED_STRING_CONTENT", "LDQUOTE", 
		"LPAR", "INTERPOLATION_START", "RPAR", "WORD", "AND", "PIPE", "OR", "NOT", 
		"SEMICOLON", "NEWLINES", "ESCAPE_NEWLINE", "COMMENT", "SPACES", "TEXT", 
		"INTERPOLATION_START_IN_DSTRING", "ESCAPE_SEQUENCE", "RDQUOTE"
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
		4,0,20,149,6,-1,6,-1,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,2,4,7,4,2,5,7,5,2,
		6,7,6,2,7,7,7,2,8,7,8,2,9,7,9,2,10,7,10,2,11,7,11,2,12,7,12,2,13,7,13,
		2,14,7,14,2,15,7,15,2,16,7,16,2,17,7,17,2,18,7,18,2,19,7,19,2,20,7,20,
		1,0,1,0,1,0,1,0,1,0,1,0,3,0,51,8,0,1,1,1,1,1,1,1,1,1,2,5,2,58,8,2,10,2,
		12,2,61,9,2,1,3,1,3,1,3,1,3,1,4,1,4,1,4,1,4,1,5,1,5,1,5,1,5,1,5,1,6,1,
		6,1,6,1,6,1,7,4,7,81,8,7,11,7,12,7,82,1,8,1,8,1,8,1,9,1,9,1,10,1,10,1,
		10,1,11,1,11,1,11,1,12,1,12,1,13,1,13,1,13,5,13,101,8,13,10,13,12,13,104,
		9,13,1,14,1,14,3,14,108,8,14,1,14,3,14,111,8,14,1,14,1,14,1,14,1,14,1,
		15,1,15,5,15,119,8,15,10,15,12,15,122,9,15,1,15,1,15,1,16,4,16,127,8,16,
		11,16,12,16,128,1,16,1,16,1,17,4,17,134,8,17,11,17,12,17,135,1,18,1,18,
		1,18,1,18,1,18,1,19,1,19,1,19,1,20,1,20,1,20,1,20,1,59,0,21,2,1,4,2,6,
		0,8,3,10,4,12,5,14,6,16,7,18,8,20,9,22,10,24,11,26,12,28,13,30,14,32,15,
		34,16,36,17,38,18,40,19,42,20,2,0,1,4,7,0,37,37,43,57,61,61,64,91,93,95,
		97,123,125,125,1,0,10,10,2,0,9,9,32,32,3,0,34,34,36,36,92,92,156,0,2,1,
		0,0,0,0,4,1,0,0,0,0,8,1,0,0,0,0,10,1,0,0,0,0,12,1,0,0,0,0,14,1,0,0,0,0,
		16,1,0,0,0,0,18,1,0,0,0,0,20,1,0,0,0,0,22,1,0,0,0,0,24,1,0,0,0,0,26,1,
		0,0,0,0,28,1,0,0,0,0,30,1,0,0,0,0,32,1,0,0,0,0,34,1,0,0,0,1,36,1,0,0,0,
		1,38,1,0,0,0,1,40,1,0,0,0,1,42,1,0,0,0,2,50,1,0,0,0,4,52,1,0,0,0,6,59,
		1,0,0,0,8,62,1,0,0,0,10,66,1,0,0,0,12,70,1,0,0,0,14,75,1,0,0,0,16,80,1,
		0,0,0,18,84,1,0,0,0,20,87,1,0,0,0,22,89,1,0,0,0,24,92,1,0,0,0,26,95,1,
		0,0,0,28,97,1,0,0,0,30,105,1,0,0,0,32,116,1,0,0,0,34,126,1,0,0,0,36,133,
		1,0,0,0,38,137,1,0,0,0,40,142,1,0,0,0,42,145,1,0,0,0,44,45,5,34,0,0,45,
		46,5,34,0,0,46,51,5,34,0,0,47,48,5,39,0,0,48,49,5,39,0,0,49,51,5,39,0,
		0,50,44,1,0,0,0,50,47,1,0,0,0,51,3,1,0,0,0,52,53,5,39,0,0,53,54,3,6,2,
		0,54,55,5,39,0,0,55,5,1,0,0,0,56,58,9,0,0,0,57,56,1,0,0,0,58,61,1,0,0,
		0,59,60,1,0,0,0,59,57,1,0,0,0,60,7,1,0,0,0,61,59,1,0,0,0,62,63,5,34,0,
		0,63,64,1,0,0,0,64,65,6,3,0,0,65,9,1,0,0,0,66,67,5,40,0,0,67,68,1,0,0,
		0,68,69,6,4,1,0,69,11,1,0,0,0,70,71,5,36,0,0,71,72,5,40,0,0,72,73,1,0,
		0,0,73,74,6,5,1,0,74,13,1,0,0,0,75,76,5,41,0,0,76,77,1,0,0,0,77,78,6,6,
		2,0,78,15,1,0,0,0,79,81,7,0,0,0,80,79,1,0,0,0,81,82,1,0,0,0,82,80,1,0,
		0,0,82,83,1,0,0,0,83,17,1,0,0,0,84,85,5,38,0,0,85,86,5,38,0,0,86,19,1,
		0,0,0,87,88,5,124,0,0,88,21,1,0,0,0,89,90,5,124,0,0,90,91,5,124,0,0,91,
		23,1,0,0,0,92,93,5,33,0,0,93,94,3,34,16,0,94,25,1,0,0,0,95,96,5,59,0,0,
		96,27,1,0,0,0,97,102,5,10,0,0,98,101,3,34,16,0,99,101,5,10,0,0,100,98,
		1,0,0,0,100,99,1,0,0,0,101,104,1,0,0,0,102,100,1,0,0,0,102,103,1,0,0,0,
		103,29,1,0,0,0,104,102,1,0,0,0,105,107,5,92,0,0,106,108,3,34,16,0,107,
		106,1,0,0,0,107,108,1,0,0,0,108,110,1,0,0,0,109,111,3,32,15,0,110,109,
		1,0,0,0,110,111,1,0,0,0,111,112,1,0,0,0,112,113,5,10,0,0,113,114,1,0,0,
		0,114,115,6,14,3,0,115,31,1,0,0,0,116,120,5,35,0,0,117,119,8,1,0,0,118,
		117,1,0,0,0,119,122,1,0,0,0,120,118,1,0,0,0,120,121,1,0,0,0,121,123,1,
		0,0,0,122,120,1,0,0,0,123,124,6,15,3,0,124,33,1,0,0,0,125,127,7,2,0,0,
		126,125,1,0,0,0,127,128,1,0,0,0,128,126,1,0,0,0,128,129,1,0,0,0,129,130,
		1,0,0,0,130,131,6,16,3,0,131,35,1,0,0,0,132,134,8,3,0,0,133,132,1,0,0,
		0,134,135,1,0,0,0,135,133,1,0,0,0,135,136,1,0,0,0,136,37,1,0,0,0,137,138,
		5,36,0,0,138,139,5,40,0,0,139,140,1,0,0,0,140,141,6,18,1,0,141,39,1,0,
		0,0,142,143,5,92,0,0,143,144,9,0,0,0,144,41,1,0,0,0,145,146,5,34,0,0,146,
		147,1,0,0,0,147,148,6,20,2,0,148,43,1,0,0,0,13,0,1,50,59,80,82,100,102,
		107,110,120,128,135,4,5,1,0,5,0,0,4,0,0,6,0,0
	]

	public
	static let _ATN: ATN = try! ATNDeserializer().deserialize(_serializedATN)
}