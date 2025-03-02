// Generated from ./grammar/ShellParser.g4 by ANTLR 4.13.1
import Antlr4

open class ShellParser: Parser {

	internal static var _decisionToDFA: [DFA] = {
          var decisionToDFA = [DFA]()
          let length = ShellParser._ATN.getNumberOfDecisions()
          for i in 0..<length {
            decisionToDFA.append(DFA(ShellParser._ATN.getDecisionState(i)!, i))
           }
           return decisionToDFA
     }()

	internal static let _sharedContextCache = PredictionContextCache()

	public
	enum Tokens: Int {
		case EOF = -1, TRIPLE_QUOTE = 1, SINGLE_QUOTED_STRING = 2, LDQUOTE = 3, 
                 LPAR = 4, INTERPOLATION_START = 5, RPAR = 6, ELIF = 7, 
                 IF = 8, SWITCH = 9, CASE = 10, DO = 11, THEN = 12, ELSE = 13, 
                 FOR = 14, WHILE = 15, CATCH = 16, IN = 17, END = 18, DEFER = 19, 
                 AND = 20, PIPE = 21, OR = 22, SEMICOLON = 23, NL = 24, 
                 WORD = 25, ARG = 26, ESCAPE_NEWLINE = 27, COMMENT = 28, 
                 SPACES = 29, ANY = 30, TEXT = 31, INTERPOLATION_START_IN_DSTRING = 32, 
                 ESCAPE_SEQUENCE = 33, RDQUOTE = 34
	}

	public
	static let RULE_root = 0, RULE_cmds = 1, RULE_cmd = 2, RULE_arg = 3, RULE_dStringFragment = 4

	public
	static let ruleNames: [String] = [
		"root", "cmds", "cmd", "arg", "dStringFragment"
	]

	private static let _LITERAL_NAMES: [String?] = [
		nil, nil, nil, nil, "'('", nil, "')'", nil, nil, nil, nil, nil, nil, nil, 
		nil, nil, nil, nil, nil, nil, "'&&'", "'|'", "'||'", "';'"
	]
	private static let _SYMBOLIC_NAMES: [String?] = [
		nil, "TRIPLE_QUOTE", "SINGLE_QUOTED_STRING", "LDQUOTE", "LPAR", "INTERPOLATION_START", 
		"RPAR", "ELIF", "IF", "SWITCH", "CASE", "DO", "THEN", "ELSE", "FOR", "WHILE", 
		"CATCH", "IN", "END", "DEFER", "AND", "PIPE", "OR", "SEMICOLON", "NL", 
		"WORD", "ARG", "ESCAPE_NEWLINE", "COMMENT", "SPACES", "ANY", "TEXT", "INTERPOLATION_START_IN_DSTRING", 
		"ESCAPE_SEQUENCE", "RDQUOTE"
	]
	public
	static let VOCABULARY = Vocabulary(_LITERAL_NAMES, _SYMBOLIC_NAMES)

	override open
	func getGrammarFileName() -> String { return "ShellParser.g4" }

	override open
	func getRuleNames() -> [String] { return ShellParser.ruleNames }

	override open
	func getSerializedATN() -> [Int] { return ShellParser._serializedATN }

	override open
	func getATN() -> ATN { return ShellParser._ATN }


	override open
	func getVocabulary() -> Vocabulary {
	    return ShellParser.VOCABULARY
	}

	override public
	init(_ input:TokenStream) throws {
	    RuntimeMetaData.checkVersion("4.13.1", RuntimeMetaData.VERSION)
		try super.init(input)
		_interp = ParserATNSimulator(self,ShellParser._ATN,ShellParser._decisionToDFA, ShellParser._sharedContextCache)
	}


	public class RootContext: ParserRuleContext {
			open
			func cmds() -> CmdsContext? {
				return getRuleContext(CmdsContext.self, 0)
			}
			open
			func EOF() -> TerminalNode? {
				return getToken(ShellParser.Tokens.EOF.rawValue, 0)
			}
			open
			func NL() -> [TerminalNode] {
				return getTokens(ShellParser.Tokens.NL.rawValue)
			}
			open
			func NL(_ i:Int) -> TerminalNode? {
				return getToken(ShellParser.Tokens.NL.rawValue, i)
			}
		override open
		func getRuleIndex() -> Int {
			return ShellParser.RULE_root
		}
	}
	@discardableResult
	 open func root() throws -> RootContext {
		var _localctx: RootContext
		_localctx = RootContext(_ctx, getState())
		try enterRule(_localctx, 0, ShellParser.RULE_root)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(13)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (_la == ShellParser.Tokens.NL.rawValue) {
		 		setState(10)
		 		try match(ShellParser.Tokens.NL.rawValue)


		 		setState(15)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	}
		 	setState(20)
		 	try _errHandler.sync(self)
		 	switch (ShellParser.Tokens(rawValue: try _input.LA(1))!) {
		 	case .LPAR:fallthrough
		 	case .IF:fallthrough
		 	case .WORD:
		 		setState(16)
		 		try cmds()
		 		setState(17)
		 		try match(ShellParser.Tokens.EOF.rawValue)

		 		break

		 	case .EOF:
		 		setState(19)
		 		try match(ShellParser.Tokens.EOF.rawValue)

		 		break
		 	default:
		 		throw ANTLRException.recognition(e: NoViableAltException(self))
		 	}

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class CmdsContext: ParserRuleContext {
		override open
		func getRuleIndex() -> Int {
			return ShellParser.RULE_cmds
		}
	}
	public class IfElseContext: CmdsContext {
			open
			func IF() -> TerminalNode? {
				return getToken(ShellParser.Tokens.IF.rawValue, 0)
			}
			open
			func cmd() -> [CmdContext] {
				return getRuleContexts(CmdContext.self)
			}
			open
			func cmd(_ i: Int) -> CmdContext? {
				return getRuleContext(CmdContext.self, i)
			}
			open
			func THEN() -> [TerminalNode] {
				return getTokens(ShellParser.Tokens.THEN.rawValue)
			}
			open
			func THEN(_ i:Int) -> TerminalNode? {
				return getToken(ShellParser.Tokens.THEN.rawValue, i)
			}
			open
			func END() -> TerminalNode? {
				return getToken(ShellParser.Tokens.END.rawValue, 0)
			}
			open
			func cmds() -> [CmdsContext] {
				return getRuleContexts(CmdsContext.self)
			}
			open
			func cmds(_ i: Int) -> CmdsContext? {
				return getRuleContext(CmdsContext.self, i)
			}
			open
			func ELIF() -> [TerminalNode] {
				return getTokens(ShellParser.Tokens.ELIF.rawValue)
			}
			open
			func ELIF(_ i:Int) -> TerminalNode? {
				return getToken(ShellParser.Tokens.ELIF.rawValue, i)
			}
			open
			func ELSE() -> TerminalNode? {
				return getToken(ShellParser.Tokens.ELSE.rawValue, 0)
			}

		public
		init(_ ctx: CmdsContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class SeqContext: CmdsContext {
			open
			func cmd() -> CmdContext? {
				return getRuleContext(CmdContext.self, 0)
			}
			open
			func cmds() -> [CmdsContext] {
				return getRuleContexts(CmdsContext.self)
			}
			open
			func cmds(_ i: Int) -> CmdsContext? {
				return getRuleContext(CmdsContext.self, i)
			}
			open
			func SEMICOLON() -> [TerminalNode] {
				return getTokens(ShellParser.Tokens.SEMICOLON.rawValue)
			}
			open
			func SEMICOLON(_ i:Int) -> TerminalNode? {
				return getToken(ShellParser.Tokens.SEMICOLON.rawValue, i)
			}
			open
			func NL() -> [TerminalNode] {
				return getTokens(ShellParser.Tokens.NL.rawValue)
			}
			open
			func NL(_ i:Int) -> TerminalNode? {
				return getToken(ShellParser.Tokens.NL.rawValue, i)
			}

		public
		init(_ ctx: CmdsContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	@discardableResult
	 open func cmds() throws -> CmdsContext {
		var _localctx: CmdsContext
		_localctx = CmdsContext(_ctx, getState())
		try enterRule(_localctx, 2, ShellParser.RULE_cmds)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
			var _alt:Int
		 	setState(60)
		 	try _errHandler.sync(self)
		 	switch(try getInterpreter().adaptivePredict(_input,9, _ctx)) {
		 	case 1:
		 		_localctx =  IfElseContext(_localctx);
		 		try enterOuterAlt(_localctx, 1)
		 		setState(22)
		 		try match(ShellParser.Tokens.IF.rawValue)
		 		setState(23)
		 		try cmd(0)
		 		setState(24)
		 		try match(ShellParser.Tokens.THEN.rawValue)
		 		setState(26)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 		if (((Int64(_la) & ~0x3f) == 0 && ((Int64(1) << _la) & 33554704) != 0)) {
		 			setState(25)
		 			try cmds()

		 		}

		 		setState(36)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 		while (_la == ShellParser.Tokens.ELIF.rawValue) {
		 			setState(28)
		 			try match(ShellParser.Tokens.ELIF.rawValue)
		 			setState(29)
		 			try cmd(0)
		 			setState(30)
		 			try match(ShellParser.Tokens.THEN.rawValue)
		 			setState(32)
		 			try _errHandler.sync(self)
		 			_la = try _input.LA(1)
		 			if (((Int64(_la) & ~0x3f) == 0 && ((Int64(1) << _la) & 33554704) != 0)) {
		 				setState(31)
		 				try cmds()

		 			}



		 			setState(38)
		 			try _errHandler.sync(self)
		 			_la = try _input.LA(1)
		 		}
		 		setState(43)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 		if (_la == ShellParser.Tokens.ELSE.rawValue) {
		 			setState(39)
		 			try match(ShellParser.Tokens.ELSE.rawValue)
		 			setState(41)
		 			try _errHandler.sync(self)
		 			_la = try _input.LA(1)
		 			if (((Int64(_la) & ~0x3f) == 0 && ((Int64(1) << _la) & 33554704) != 0)) {
		 				setState(40)
		 				try cmds()

		 			}


		 		}

		 		setState(45)
		 		try match(ShellParser.Tokens.END.rawValue)

		 		break
		 	case 2:
		 		_localctx =  SeqContext(_localctx);
		 		try enterOuterAlt(_localctx, 2)
		 		setState(47)
		 		try cmd(0)
		 		setState(49); 
		 		try _errHandler.sync(self)
		 		_alt = 1;
		 		repeat {
		 			switch (_alt) {
		 			case 1:
		 				setState(48)
		 				_la = try _input.LA(1)
		 				if (!(_la == ShellParser.Tokens.SEMICOLON.rawValue || _la == ShellParser.Tokens.NL.rawValue)) {
		 				try _errHandler.recoverInline(self)
		 				}
		 				else {
		 					_errHandler.reportMatch(self)
		 					try consume()
		 				}


		 				break
		 			default:
		 				throw ANTLRException.recognition(e: NoViableAltException(self))
		 			}
		 			setState(51); 
		 			try _errHandler.sync(self)
		 			_alt = try getInterpreter().adaptivePredict(_input,7,_ctx)
		 		} while (_alt != 2 && _alt !=  ATN.INVALID_ALT_NUMBER)
		 		setState(56)
		 		try _errHandler.sync(self)
		 		_alt = try getInterpreter().adaptivePredict(_input,8,_ctx)
		 		while (_alt != 1 && _alt != ATN.INVALID_ALT_NUMBER) {
		 			if ( _alt==1+1 ) {
		 				setState(53)
		 				try cmds()

		 		 
		 			}
		 			setState(58)
		 			try _errHandler.sync(self)
		 			_alt = try getInterpreter().adaptivePredict(_input,8,_ctx)
		 		}

		 		break
		 	case 3:
		 		_localctx =  SeqContext(_localctx);
		 		try enterOuterAlt(_localctx, 3)
		 		setState(59)
		 		try cmd(0)

		 		break
		 	default: break
		 	}
		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}


	public class CmdContext: ParserRuleContext {
		override open
		func getRuleIndex() -> Int {
			return ShellParser.RULE_cmd
		}
	}
	public class ArgsContext: CmdContext {
			open
			func WORD() -> TerminalNode? {
				return getToken(ShellParser.Tokens.WORD.rawValue, 0)
			}
			open
			func arg() -> [ArgContext] {
				return getRuleContexts(ArgContext.self)
			}
			open
			func arg(_ i: Int) -> ArgContext? {
				return getRuleContext(ArgContext.self, i)
			}

		public
		init(_ ctx: CmdContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class CmdErrorContext: CmdContext {
			open
			func LPAR() -> TerminalNode? {
				return getToken(ShellParser.Tokens.LPAR.rawValue, 0)
			}
			open
			func cmds() -> CmdsContext? {
				return getRuleContext(CmdsContext.self, 0)
			}
			open
			func RPAR() -> [TerminalNode] {
				return getTokens(ShellParser.Tokens.RPAR.rawValue)
			}
			open
			func RPAR(_ i:Int) -> TerminalNode? {
				return getToken(ShellParser.Tokens.RPAR.rawValue, i)
			}

		public
		init(_ ctx: CmdContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class OrContext: CmdContext {
			open
			func cmd() -> [CmdContext] {
				return getRuleContexts(CmdContext.self)
			}
			open
			func cmd(_ i: Int) -> CmdContext? {
				return getRuleContext(CmdContext.self, i)
			}
			open
			func OR() -> TerminalNode? {
				return getToken(ShellParser.Tokens.OR.rawValue, 0)
			}
			open
			func NL() -> [TerminalNode] {
				return getTokens(ShellParser.Tokens.NL.rawValue)
			}
			open
			func NL(_ i:Int) -> TerminalNode? {
				return getToken(ShellParser.Tokens.NL.rawValue, i)
			}

		public
		init(_ ctx: CmdContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class ParensContext: CmdContext {
			open
			func LPAR() -> TerminalNode? {
				return getToken(ShellParser.Tokens.LPAR.rawValue, 0)
			}
			open
			func cmds() -> CmdsContext? {
				return getRuleContext(CmdsContext.self, 0)
			}
			open
			func RPAR() -> TerminalNode? {
				return getToken(ShellParser.Tokens.RPAR.rawValue, 0)
			}

		public
		init(_ ctx: CmdContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class AndContext: CmdContext {
			open
			func cmd() -> [CmdContext] {
				return getRuleContexts(CmdContext.self)
			}
			open
			func cmd(_ i: Int) -> CmdContext? {
				return getRuleContext(CmdContext.self, i)
			}
			open
			func AND() -> TerminalNode? {
				return getToken(ShellParser.Tokens.AND.rawValue, 0)
			}
			open
			func NL() -> [TerminalNode] {
				return getTokens(ShellParser.Tokens.NL.rawValue)
			}
			open
			func NL(_ i:Int) -> TerminalNode? {
				return getToken(ShellParser.Tokens.NL.rawValue, i)
			}

		public
		init(_ ctx: CmdContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class PipeContext: CmdContext {
			open
			func cmd() -> [CmdContext] {
				return getRuleContexts(CmdContext.self)
			}
			open
			func cmd(_ i: Int) -> CmdContext? {
				return getRuleContext(CmdContext.self, i)
			}
			open
			func PIPE() -> TerminalNode? {
				return getToken(ShellParser.Tokens.PIPE.rawValue, 0)
			}
			open
			func NL() -> [TerminalNode] {
				return getTokens(ShellParser.Tokens.NL.rawValue)
			}
			open
			func NL(_ i:Int) -> TerminalNode? {
				return getToken(ShellParser.Tokens.NL.rawValue, i)
			}

		public
		init(_ ctx: CmdContext) {
			super.init()
			copyFrom(ctx)
		}
	}

	 public final  func cmd( ) throws -> CmdContext   {
		return try cmd(0)
	}
	@discardableResult
	private func cmd(_ _p: Int) throws -> CmdContext   {
		let _parentctx: ParserRuleContext? = _ctx
		let _parentState: Int = getState()
		var _localctx: CmdContext
		_localctx = CmdContext(_ctx, _parentState)
		let _startState: Int = 4
		try enterRecursionRule(_localctx, 4, ShellParser.RULE_cmd, _p)
		var _la: Int = 0
		defer {
	    		try! unrollRecursionContexts(_parentctx)
	    }
		do {
			var _alt: Int
			try enterOuterAlt(_localctx, 1)
			setState(84)
			try _errHandler.sync(self)
			switch(try getInterpreter().adaptivePredict(_input,11, _ctx)) {
			case 1:
				_localctx = ArgsContext(_localctx)
				_ctx = _localctx

				setState(63)
				try match(ShellParser.Tokens.WORD.rawValue)
				setState(67)
				try _errHandler.sync(self)
				_alt = try getInterpreter().adaptivePredict(_input,10,_ctx)
				while (_alt != 2 && _alt != ATN.INVALID_ALT_NUMBER) {
					if ( _alt==1 ) {
						setState(64)
						try arg()

				 
					}
					setState(69)
					try _errHandler.sync(self)
					_alt = try getInterpreter().adaptivePredict(_input,10,_ctx)
				}

				break
			case 2:
				_localctx = ParensContext(_localctx)
				_ctx = _localctx
				setState(70)
				try match(ShellParser.Tokens.LPAR.rawValue)
				setState(71)
				try cmds()
				setState(72)
				try match(ShellParser.Tokens.RPAR.rawValue)

				break
			case 3:
				_localctx = CmdErrorContext(_localctx)
				_ctx = _localctx
				setState(74)
				try match(ShellParser.Tokens.LPAR.rawValue)
				setState(75)
				try cmds()
				setState(76)
				try match(ShellParser.Tokens.RPAR.rawValue)
				setState(77)
				try match(ShellParser.Tokens.RPAR.rawValue)
				notifyErrorListeners("Unbalanced parenthesis")

				break
			case 4:
				_localctx = CmdErrorContext(_localctx)
				_ctx = _localctx
				setState(80)
				try match(ShellParser.Tokens.LPAR.rawValue)
				setState(81)
				try cmds()
				notifyErrorListeners("Unbalanced parenthesis")

				break
			default: break
			}
			_ctx!.stop = try _input.LT(-1)
			setState(115)
			try _errHandler.sync(self)
			_alt = try getInterpreter().adaptivePredict(_input,16,_ctx)
			while (_alt != 2 && _alt != ATN.INVALID_ALT_NUMBER) {
				if ( _alt==1 ) {
					if _parseListeners != nil {
					   try triggerExitRuleEvent()
					}
					setState(113)
					try _errHandler.sync(self)
					switch(try getInterpreter().adaptivePredict(_input,15, _ctx)) {
					case 1:
						_localctx = PipeContext(  CmdContext(_parentctx, _parentState))
						try pushNewRecursionContext(_localctx, _startState, ShellParser.RULE_cmd)
						setState(86)
						if (!(precpred(_ctx, 6))) {
						    throw ANTLRException.recognition(e:FailedPredicateException(self, "precpred(_ctx, 6)"))
						}
						setState(90)
						try _errHandler.sync(self)
						_la = try _input.LA(1)
						while (_la == ShellParser.Tokens.NL.rawValue) {
							setState(87)
							try match(ShellParser.Tokens.NL.rawValue)


							setState(92)
							try _errHandler.sync(self)
							_la = try _input.LA(1)
						}
						setState(93)
						try match(ShellParser.Tokens.PIPE.rawValue)
						setState(94)
						try cmd(7)

						break
					case 2:
						_localctx = AndContext(  CmdContext(_parentctx, _parentState))
						try pushNewRecursionContext(_localctx, _startState, ShellParser.RULE_cmd)
						setState(95)
						if (!(precpred(_ctx, 5))) {
						    throw ANTLRException.recognition(e:FailedPredicateException(self, "precpred(_ctx, 5)"))
						}
						setState(99)
						try _errHandler.sync(self)
						_la = try _input.LA(1)
						while (_la == ShellParser.Tokens.NL.rawValue) {
							setState(96)
							try match(ShellParser.Tokens.NL.rawValue)


							setState(101)
							try _errHandler.sync(self)
							_la = try _input.LA(1)
						}
						setState(102)
						try match(ShellParser.Tokens.AND.rawValue)
						setState(103)
						try cmd(6)

						break
					case 3:
						_localctx = OrContext(  CmdContext(_parentctx, _parentState))
						try pushNewRecursionContext(_localctx, _startState, ShellParser.RULE_cmd)
						setState(104)
						if (!(precpred(_ctx, 4))) {
						    throw ANTLRException.recognition(e:FailedPredicateException(self, "precpred(_ctx, 4)"))
						}
						setState(108)
						try _errHandler.sync(self)
						_la = try _input.LA(1)
						while (_la == ShellParser.Tokens.NL.rawValue) {
							setState(105)
							try match(ShellParser.Tokens.NL.rawValue)


							setState(110)
							try _errHandler.sync(self)
							_la = try _input.LA(1)
						}
						setState(111)
						try match(ShellParser.Tokens.OR.rawValue)
						setState(112)
						try cmd(5)

						break
					default: break
					}
			 
				}
				setState(117)
				try _errHandler.sync(self)
				_alt = try getInterpreter().adaptivePredict(_input,16,_ctx)
			}

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx;
	}

	public class ArgContext: ParserRuleContext {
		override open
		func getRuleIndex() -> Int {
			return ShellParser.RULE_arg
		}
	}
	public class WordContext: ArgContext {
			open
			func ARG() -> TerminalNode? {
				return getToken(ShellParser.Tokens.ARG.rawValue, 0)
			}
			open
			func WORD() -> TerminalNode? {
				return getToken(ShellParser.Tokens.WORD.rawValue, 0)
			}

		public
		init(_ ctx: ArgContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class SubstitutionContext: ArgContext {
			open
			func INTERPOLATION_START() -> TerminalNode? {
				return getToken(ShellParser.Tokens.INTERPOLATION_START.rawValue, 0)
			}
			open
			func cmds() -> CmdsContext? {
				return getRuleContext(CmdsContext.self, 0)
			}
			open
			func RPAR() -> TerminalNode? {
				return getToken(ShellParser.Tokens.RPAR.rawValue, 0)
			}

		public
		init(_ ctx: ArgContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class ArgErrorContext: ArgContext {
			open
			func LDQUOTE() -> TerminalNode? {
				return getToken(ShellParser.Tokens.LDQUOTE.rawValue, 0)
			}
			open
			func RDQUOTE() -> [TerminalNode] {
				return getTokens(ShellParser.Tokens.RDQUOTE.rawValue)
			}
			open
			func RDQUOTE(_ i:Int) -> TerminalNode? {
				return getToken(ShellParser.Tokens.RDQUOTE.rawValue, i)
			}
			open
			func dStringFragment() -> [DStringFragmentContext] {
				return getRuleContexts(DStringFragmentContext.self)
			}
			open
			func dStringFragment(_ i: Int) -> DStringFragmentContext? {
				return getRuleContext(DStringFragmentContext.self, i)
			}
			open
			func INTERPOLATION_START() -> TerminalNode? {
				return getToken(ShellParser.Tokens.INTERPOLATION_START.rawValue, 0)
			}
			open
			func cmds() -> CmdsContext? {
				return getRuleContext(CmdsContext.self, 0)
			}
			open
			func RPAR() -> [TerminalNode] {
				return getTokens(ShellParser.Tokens.RPAR.rawValue)
			}
			open
			func RPAR(_ i:Int) -> TerminalNode? {
				return getToken(ShellParser.Tokens.RPAR.rawValue, i)
			}

		public
		init(_ ctx: ArgContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class SQuotedStringContext: ArgContext {
			open
			func SINGLE_QUOTED_STRING() -> TerminalNode? {
				return getToken(ShellParser.Tokens.SINGLE_QUOTED_STRING.rawValue, 0)
			}

		public
		init(_ ctx: ArgContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class DQuotedStringContext: ArgContext {
			open
			func LDQUOTE() -> TerminalNode? {
				return getToken(ShellParser.Tokens.LDQUOTE.rawValue, 0)
			}
			open
			func RDQUOTE() -> TerminalNode? {
				return getToken(ShellParser.Tokens.RDQUOTE.rawValue, 0)
			}
			open
			func dStringFragment() -> [DStringFragmentContext] {
				return getRuleContexts(DStringFragmentContext.self)
			}
			open
			func dStringFragment(_ i: Int) -> DStringFragmentContext? {
				return getRuleContext(DStringFragmentContext.self, i)
			}

		public
		init(_ ctx: ArgContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	@discardableResult
	 open func arg() throws -> ArgContext {
		var _localctx: ArgContext
		_localctx = ArgContext(_ctx, getState())
		try enterRule(_localctx, 6, ShellParser.RULE_arg)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
			var _alt:Int
		 	setState(161)
		 	try _errHandler.sync(self)
		 	switch(try getInterpreter().adaptivePredict(_input,20, _ctx)) {
		 	case 1:
		 		_localctx =  WordContext(_localctx);
		 		try enterOuterAlt(_localctx, 1)
		 		setState(118)
		 		try match(ShellParser.Tokens.ARG.rawValue)

		 		break
		 	case 2:
		 		_localctx =  WordContext(_localctx);
		 		try enterOuterAlt(_localctx, 2)
		 		setState(119)
		 		try match(ShellParser.Tokens.WORD.rawValue)

		 		break
		 	case 3:
		 		_localctx =  SQuotedStringContext(_localctx);
		 		try enterOuterAlt(_localctx, 3)
		 		setState(120)
		 		try match(ShellParser.Tokens.SINGLE_QUOTED_STRING.rawValue)

		 		break
		 	case 4:
		 		_localctx =  DQuotedStringContext(_localctx);
		 		try enterOuterAlt(_localctx, 4)
		 		setState(121)
		 		try match(ShellParser.Tokens.LDQUOTE.rawValue)
		 		setState(125)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 		while (((Int64(_la) & ~0x3f) == 0 && ((Int64(1) << _la) & 15032385536) != 0)) {
		 			setState(122)
		 			try dStringFragment()


		 			setState(127)
		 			try _errHandler.sync(self)
		 			_la = try _input.LA(1)
		 		}
		 		setState(128)
		 		try match(ShellParser.Tokens.RDQUOTE.rawValue)

		 		break
		 	case 5:
		 		_localctx =  SubstitutionContext(_localctx);
		 		try enterOuterAlt(_localctx, 5)
		 		setState(129)
		 		try match(ShellParser.Tokens.INTERPOLATION_START.rawValue)
		 		setState(130)
		 		try cmds()
		 		setState(131)
		 		try match(ShellParser.Tokens.RPAR.rawValue)

		 		break
		 	case 6:
		 		_localctx =  ArgErrorContext(_localctx);
		 		try enterOuterAlt(_localctx, 6)
		 		setState(133)
		 		try match(ShellParser.Tokens.LDQUOTE.rawValue)
		 		setState(137)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 		while (((Int64(_la) & ~0x3f) == 0 && ((Int64(1) << _la) & 15032385536) != 0)) {
		 			setState(134)
		 			try dStringFragment()


		 			setState(139)
		 			try _errHandler.sync(self)
		 			_la = try _input.LA(1)
		 		}
		 		setState(140)
		 		try match(ShellParser.Tokens.RDQUOTE.rawValue)
		 		setState(141)
		 		try match(ShellParser.Tokens.RDQUOTE.rawValue)
		 		notifyErrorListeners("Unbalanced quotes")

		 		break
		 	case 7:
		 		_localctx =  ArgErrorContext(_localctx);
		 		try enterOuterAlt(_localctx, 7)
		 		setState(143)
		 		try match(ShellParser.Tokens.LDQUOTE.rawValue)
		 		setState(147)
		 		try _errHandler.sync(self)
		 		_alt = try getInterpreter().adaptivePredict(_input,19,_ctx)
		 		while (_alt != 2 && _alt != ATN.INVALID_ALT_NUMBER) {
		 			if ( _alt==1 ) {
		 				setState(144)
		 				try dStringFragment()

		 		 
		 			}
		 			setState(149)
		 			try _errHandler.sync(self)
		 			_alt = try getInterpreter().adaptivePredict(_input,19,_ctx)
		 		}
		 		notifyErrorListeners("Unbalanced quotes")

		 		break
		 	case 8:
		 		_localctx =  ArgErrorContext(_localctx);
		 		try enterOuterAlt(_localctx, 8)
		 		setState(151)
		 		try match(ShellParser.Tokens.INTERPOLATION_START.rawValue)
		 		setState(152)
		 		try cmds()
		 		setState(153)
		 		try match(ShellParser.Tokens.RPAR.rawValue)
		 		setState(154)
		 		try match(ShellParser.Tokens.RPAR.rawValue)
		 		notifyErrorListeners("Unbalanced parenthesis")

		 		break
		 	case 9:
		 		_localctx =  ArgErrorContext(_localctx);
		 		try enterOuterAlt(_localctx, 9)
		 		setState(157)
		 		try match(ShellParser.Tokens.INTERPOLATION_START.rawValue)
		 		setState(158)
		 		try cmds()
		 		notifyErrorListeners("Unbalanced parenthesis")

		 		break
		 	default: break
		 	}
		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class DStringFragmentContext: ParserRuleContext {
		override open
		func getRuleIndex() -> Int {
			return ShellParser.RULE_dStringFragment
		}
	}
	public class InterpolationContext: DStringFragmentContext {
			open
			func INTERPOLATION_START_IN_DSTRING() -> TerminalNode? {
				return getToken(ShellParser.Tokens.INTERPOLATION_START_IN_DSTRING.rawValue, 0)
			}
			open
			func cmds() -> CmdsContext? {
				return getRuleContext(CmdsContext.self, 0)
			}
			open
			func RPAR() -> TerminalNode? {
				return getToken(ShellParser.Tokens.RPAR.rawValue, 0)
			}

		public
		init(_ ctx: DStringFragmentContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class DStringFragmentErrorContext: DStringFragmentContext {
			open
			func INTERPOLATION_START_IN_DSTRING() -> TerminalNode? {
				return getToken(ShellParser.Tokens.INTERPOLATION_START_IN_DSTRING.rawValue, 0)
			}
			open
			func cmds() -> CmdsContext? {
				return getRuleContext(CmdsContext.self, 0)
			}
			open
			func RPAR() -> [TerminalNode] {
				return getTokens(ShellParser.Tokens.RPAR.rawValue)
			}
			open
			func RPAR(_ i:Int) -> TerminalNode? {
				return getToken(ShellParser.Tokens.RPAR.rawValue, i)
			}

		public
		init(_ ctx: DStringFragmentContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class EscapeSequenceContext: DStringFragmentContext {
			open
			func ESCAPE_SEQUENCE() -> TerminalNode? {
				return getToken(ShellParser.Tokens.ESCAPE_SEQUENCE.rawValue, 0)
			}

		public
		init(_ ctx: DStringFragmentContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class TextContext: DStringFragmentContext {
			open
			func TEXT() -> TerminalNode? {
				return getToken(ShellParser.Tokens.TEXT.rawValue, 0)
			}

		public
		init(_ ctx: DStringFragmentContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	@discardableResult
	 open func dStringFragment() throws -> DStringFragmentContext {
		var _localctx: DStringFragmentContext
		_localctx = DStringFragmentContext(_ctx, getState())
		try enterRule(_localctx, 8, ShellParser.RULE_dStringFragment)
		defer {
	    		try! exitRule()
	    }
		do {
		 	setState(179)
		 	try _errHandler.sync(self)
		 	switch(try getInterpreter().adaptivePredict(_input,21, _ctx)) {
		 	case 1:
		 		_localctx =  TextContext(_localctx);
		 		try enterOuterAlt(_localctx, 1)
		 		setState(163)
		 		try match(ShellParser.Tokens.TEXT.rawValue)

		 		break
		 	case 2:
		 		_localctx =  EscapeSequenceContext(_localctx);
		 		try enterOuterAlt(_localctx, 2)
		 		setState(164)
		 		try match(ShellParser.Tokens.ESCAPE_SEQUENCE.rawValue)

		 		break
		 	case 3:
		 		_localctx =  InterpolationContext(_localctx);
		 		try enterOuterAlt(_localctx, 3)
		 		setState(165)
		 		try match(ShellParser.Tokens.INTERPOLATION_START_IN_DSTRING.rawValue)
		 		setState(166)
		 		try cmds()
		 		setState(167)
		 		try match(ShellParser.Tokens.RPAR.rawValue)

		 		break
		 	case 4:
		 		_localctx =  DStringFragmentErrorContext(_localctx);
		 		try enterOuterAlt(_localctx, 4)
		 		setState(169)
		 		try match(ShellParser.Tokens.INTERPOLATION_START_IN_DSTRING.rawValue)
		 		setState(170)
		 		try cmds()
		 		setState(171)
		 		try match(ShellParser.Tokens.RPAR.rawValue)
		 		setState(172)
		 		try match(ShellParser.Tokens.RPAR.rawValue)
		 		notifyErrorListeners("Unbalanced parenthesis")

		 		break
		 	case 5:
		 		_localctx =  DStringFragmentErrorContext(_localctx);
		 		try enterOuterAlt(_localctx, 5)
		 		setState(175)
		 		try match(ShellParser.Tokens.INTERPOLATION_START_IN_DSTRING.rawValue)
		 		setState(176)
		 		try cmds()
		 		notifyErrorListeners("Unbalanced parenthesis")

		 		break
		 	default: break
		 	}
		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	override open
	func sempred(_ _localctx: RuleContext?, _ ruleIndex: Int,  _ predIndex: Int)throws -> Bool {
		switch (ruleIndex) {
		case  2:
			return try cmd_sempred(_localctx?.castdown(CmdContext.self), predIndex)
	    default: return true
		}
	}
	private func cmd_sempred(_ _localctx: CmdContext!,  _ predIndex: Int) throws -> Bool {
		switch (predIndex) {
		    case 0:return precpred(_ctx, 6)
		    case 1:return precpred(_ctx, 5)
		    case 2:return precpred(_ctx, 4)
		    default: return true
		}
	}

	static let _serializedATN:[Int] = [
		4,1,34,182,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,2,4,7,4,1,0,5,0,12,8,0,10,0,
		12,0,15,9,0,1,0,1,0,1,0,1,0,3,0,21,8,0,1,1,1,1,1,1,1,1,3,1,27,8,1,1,1,
		1,1,1,1,1,1,3,1,33,8,1,5,1,35,8,1,10,1,12,1,38,9,1,1,1,1,1,3,1,42,8,1,
		3,1,44,8,1,1,1,1,1,1,1,1,1,4,1,50,8,1,11,1,12,1,51,1,1,5,1,55,8,1,10,1,
		12,1,58,9,1,1,1,3,1,61,8,1,1,2,1,2,1,2,5,2,66,8,2,10,2,12,2,69,9,2,1,2,
		1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,3,2,85,8,2,1,2,1,2,
		5,2,89,8,2,10,2,12,2,92,9,2,1,2,1,2,1,2,1,2,5,2,98,8,2,10,2,12,2,101,9,
		2,1,2,1,2,1,2,1,2,5,2,107,8,2,10,2,12,2,110,9,2,1,2,1,2,5,2,114,8,2,10,
		2,12,2,117,9,2,1,3,1,3,1,3,1,3,1,3,5,3,124,8,3,10,3,12,3,127,9,3,1,3,1,
		3,1,3,1,3,1,3,1,3,1,3,5,3,136,8,3,10,3,12,3,139,9,3,1,3,1,3,1,3,1,3,1,
		3,5,3,146,8,3,10,3,12,3,149,9,3,1,3,1,3,1,3,1,3,1,3,1,3,1,3,1,3,1,3,1,
		3,1,3,3,3,162,8,3,1,4,1,4,1,4,1,4,1,4,1,4,1,4,1,4,1,4,1,4,1,4,1,4,1,4,
		1,4,1,4,1,4,3,4,180,8,4,1,4,1,56,1,4,5,0,2,4,6,8,0,1,1,0,23,24,212,0,13,
		1,0,0,0,2,60,1,0,0,0,4,84,1,0,0,0,6,161,1,0,0,0,8,179,1,0,0,0,10,12,5,
		24,0,0,11,10,1,0,0,0,12,15,1,0,0,0,13,11,1,0,0,0,13,14,1,0,0,0,14,20,1,
		0,0,0,15,13,1,0,0,0,16,17,3,2,1,0,17,18,5,0,0,1,18,21,1,0,0,0,19,21,5,
		0,0,1,20,16,1,0,0,0,20,19,1,0,0,0,21,1,1,0,0,0,22,23,5,8,0,0,23,24,3,4,
		2,0,24,26,5,12,0,0,25,27,3,2,1,0,26,25,1,0,0,0,26,27,1,0,0,0,27,36,1,0,
		0,0,28,29,5,7,0,0,29,30,3,4,2,0,30,32,5,12,0,0,31,33,3,2,1,0,32,31,1,0,
		0,0,32,33,1,0,0,0,33,35,1,0,0,0,34,28,1,0,0,0,35,38,1,0,0,0,36,34,1,0,
		0,0,36,37,1,0,0,0,37,43,1,0,0,0,38,36,1,0,0,0,39,41,5,13,0,0,40,42,3,2,
		1,0,41,40,1,0,0,0,41,42,1,0,0,0,42,44,1,0,0,0,43,39,1,0,0,0,43,44,1,0,
		0,0,44,45,1,0,0,0,45,46,5,18,0,0,46,61,1,0,0,0,47,49,3,4,2,0,48,50,7,0,
		0,0,49,48,1,0,0,0,50,51,1,0,0,0,51,49,1,0,0,0,51,52,1,0,0,0,52,56,1,0,
		0,0,53,55,3,2,1,0,54,53,1,0,0,0,55,58,1,0,0,0,56,57,1,0,0,0,56,54,1,0,
		0,0,57,61,1,0,0,0,58,56,1,0,0,0,59,61,3,4,2,0,60,22,1,0,0,0,60,47,1,0,
		0,0,60,59,1,0,0,0,61,3,1,0,0,0,62,63,6,2,-1,0,63,67,5,25,0,0,64,66,3,6,
		3,0,65,64,1,0,0,0,66,69,1,0,0,0,67,65,1,0,0,0,67,68,1,0,0,0,68,85,1,0,
		0,0,69,67,1,0,0,0,70,71,5,4,0,0,71,72,3,2,1,0,72,73,5,6,0,0,73,85,1,0,
		0,0,74,75,5,4,0,0,75,76,3,2,1,0,76,77,5,6,0,0,77,78,5,6,0,0,78,79,6,2,
		-1,0,79,85,1,0,0,0,80,81,5,4,0,0,81,82,3,2,1,0,82,83,6,2,-1,0,83,85,1,
		0,0,0,84,62,1,0,0,0,84,70,1,0,0,0,84,74,1,0,0,0,84,80,1,0,0,0,85,115,1,
		0,0,0,86,90,10,6,0,0,87,89,5,24,0,0,88,87,1,0,0,0,89,92,1,0,0,0,90,88,
		1,0,0,0,90,91,1,0,0,0,91,93,1,0,0,0,92,90,1,0,0,0,93,94,5,21,0,0,94,114,
		3,4,2,7,95,99,10,5,0,0,96,98,5,24,0,0,97,96,1,0,0,0,98,101,1,0,0,0,99,
		97,1,0,0,0,99,100,1,0,0,0,100,102,1,0,0,0,101,99,1,0,0,0,102,103,5,20,
		0,0,103,114,3,4,2,6,104,108,10,4,0,0,105,107,5,24,0,0,106,105,1,0,0,0,
		107,110,1,0,0,0,108,106,1,0,0,0,108,109,1,0,0,0,109,111,1,0,0,0,110,108,
		1,0,0,0,111,112,5,22,0,0,112,114,3,4,2,5,113,86,1,0,0,0,113,95,1,0,0,0,
		113,104,1,0,0,0,114,117,1,0,0,0,115,113,1,0,0,0,115,116,1,0,0,0,116,5,
		1,0,0,0,117,115,1,0,0,0,118,162,5,26,0,0,119,162,5,25,0,0,120,162,5,2,
		0,0,121,125,5,3,0,0,122,124,3,8,4,0,123,122,1,0,0,0,124,127,1,0,0,0,125,
		123,1,0,0,0,125,126,1,0,0,0,126,128,1,0,0,0,127,125,1,0,0,0,128,162,5,
		34,0,0,129,130,5,5,0,0,130,131,3,2,1,0,131,132,5,6,0,0,132,162,1,0,0,0,
		133,137,5,3,0,0,134,136,3,8,4,0,135,134,1,0,0,0,136,139,1,0,0,0,137,135,
		1,0,0,0,137,138,1,0,0,0,138,140,1,0,0,0,139,137,1,0,0,0,140,141,5,34,0,
		0,141,142,5,34,0,0,142,162,6,3,-1,0,143,147,5,3,0,0,144,146,3,8,4,0,145,
		144,1,0,0,0,146,149,1,0,0,0,147,145,1,0,0,0,147,148,1,0,0,0,148,150,1,
		0,0,0,149,147,1,0,0,0,150,162,6,3,-1,0,151,152,5,5,0,0,152,153,3,2,1,0,
		153,154,5,6,0,0,154,155,5,6,0,0,155,156,6,3,-1,0,156,162,1,0,0,0,157,158,
		5,5,0,0,158,159,3,2,1,0,159,160,6,3,-1,0,160,162,1,0,0,0,161,118,1,0,0,
		0,161,119,1,0,0,0,161,120,1,0,0,0,161,121,1,0,0,0,161,129,1,0,0,0,161,
		133,1,0,0,0,161,143,1,0,0,0,161,151,1,0,0,0,161,157,1,0,0,0,162,7,1,0,
		0,0,163,180,5,31,0,0,164,180,5,33,0,0,165,166,5,32,0,0,166,167,3,2,1,0,
		167,168,5,6,0,0,168,180,1,0,0,0,169,170,5,32,0,0,170,171,3,2,1,0,171,172,
		5,6,0,0,172,173,5,6,0,0,173,174,6,4,-1,0,174,180,1,0,0,0,175,176,5,32,
		0,0,176,177,3,2,1,0,177,178,6,4,-1,0,178,180,1,0,0,0,179,163,1,0,0,0,179,
		164,1,0,0,0,179,165,1,0,0,0,179,169,1,0,0,0,179,175,1,0,0,0,180,9,1,0,
		0,0,22,13,20,26,32,36,41,43,51,56,60,67,84,90,99,108,113,115,125,137,147,
		161,179
	]

	public
	static let _ATN = try! ATNDeserializer().deserialize(_serializedATN)
}