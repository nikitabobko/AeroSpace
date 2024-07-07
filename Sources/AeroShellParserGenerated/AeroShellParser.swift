// Generated from ./grammar/AeroShellParser.g4 by ANTLR 4.13.1
import Antlr4

open class AeroShellParser: Parser {

	internal static var _decisionToDFA: [DFA] = {
          var decisionToDFA = [DFA]()
          let length = AeroShellParser._ATN.getNumberOfDecisions()
          for i in 0..<length {
            decisionToDFA.append(DFA(AeroShellParser._ATN.getDecisionState(i)!, i))
           }
           return decisionToDFA
     }()

	internal static let _sharedContextCache = PredictionContextCache()

	public
	enum Tokens: Int {
		case EOF = -1, RESERVED = 1, SINGLE_QUOTED_STRING = 2, LDQUOTE = 3, LPAR = 4, 
                 INTERPOLATION_START = 5, RPAR = 6, WORD = 7, AND = 8, PIPE = 9, 
                 OR = 10, NOT = 11, SEMICOLON = 12, NEWLINES = 13, ESCAPE_NEWLINE = 14, 
                 COMMENT = 15, SPACES = 16, TEXT = 17, INTERPOLATION_START_IN_DSTRING = 18, 
                 ESCAPE_SEQUENCE = 19, RDQUOTE = 20
	}

	public
	static let RULE_root = 0, RULE_program = 1, RULE_arg = 2, RULE_dStringFragment = 3

	public
	static let ruleNames: [String] = [
		"root", "program", "arg", "dStringFragment"
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
	func getGrammarFileName() -> String { return "AeroShellParser.g4" }

	override open
	func getRuleNames() -> [String] { return AeroShellParser.ruleNames }

	override open
	func getSerializedATN() -> [Int] { return AeroShellParser._serializedATN }

	override open
	func getATN() -> ATN { return AeroShellParser._ATN }


	override open
	func getVocabulary() -> Vocabulary {
	    return AeroShellParser.VOCABULARY
	}

	override public
	init(_ input:TokenStream) throws {
	    RuntimeMetaData.checkVersion("4.13.1", RuntimeMetaData.VERSION)
		try super.init(input)
		_interp = ParserATNSimulator(self,AeroShellParser._ATN,AeroShellParser._decisionToDFA, AeroShellParser._sharedContextCache)
	}


	public class RootContext: ParserRuleContext {
			open
			func program() -> ProgramContext? {
				return getRuleContext(ProgramContext.self, 0)
			}
			open
			func EOF() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.EOF.rawValue, 0)
			}
		override open
		func getRuleIndex() -> Int {
			return AeroShellParser.RULE_root
		}
	}
	@discardableResult
	 open func root() throws -> RootContext {
		var _localctx: RootContext
		_localctx = RootContext(_ctx, getState())
		try enterRule(_localctx, 0, AeroShellParser.RULE_root)
		defer {
	    		try! exitRule()
	    }
		do {
		 	setState(12)
		 	try _errHandler.sync(self)
		 	switch (AeroShellParser.Tokens(rawValue: try _input.LA(1))!) {
		 	case .SINGLE_QUOTED_STRING:fallthrough
		 	case .LDQUOTE:fallthrough
		 	case .LPAR:fallthrough
		 	case .INTERPOLATION_START:fallthrough
		 	case .WORD:fallthrough
		 	case .NOT:
		 		try enterOuterAlt(_localctx, 1)
		 		setState(8)
		 		try program(0)
		 		setState(9)
		 		try match(AeroShellParser.Tokens.EOF.rawValue)

		 		break

		 	case .EOF:
		 		try enterOuterAlt(_localctx, 2)
		 		setState(11)
		 		try match(AeroShellParser.Tokens.EOF.rawValue)

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


	public class ProgramContext: ParserRuleContext {
		override open
		func getRuleIndex() -> Int {
			return AeroShellParser.RULE_program
		}
	}
	public class NotContext: ProgramContext {
			open
			func NOT() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.NOT.rawValue, 0)
			}
			open
			func program() -> ProgramContext? {
				return getRuleContext(ProgramContext.self, 0)
			}

		public
		init(_ ctx: ProgramContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class ArgsContext: ProgramContext {
			open
			func arg() -> [ArgContext] {
				return getRuleContexts(ArgContext.self)
			}
			open
			func arg(_ i: Int) -> ArgContext? {
				return getRuleContext(ArgContext.self, i)
			}

		public
		init(_ ctx: ProgramContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class OrContext: ProgramContext {
			open
			func program() -> [ProgramContext] {
				return getRuleContexts(ProgramContext.self)
			}
			open
			func program(_ i: Int) -> ProgramContext? {
				return getRuleContext(ProgramContext.self, i)
			}
			open
			func OR() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.OR.rawValue, 0)
			}
			open
			func NEWLINES() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.NEWLINES.rawValue, 0)
			}

		public
		init(_ ctx: ProgramContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class ParensContext: ProgramContext {
			open
			func LPAR() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.LPAR.rawValue, 0)
			}
			open
			func program() -> ProgramContext? {
				return getRuleContext(ProgramContext.self, 0)
			}
			open
			func RPAR() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.RPAR.rawValue, 0)
			}

		public
		init(_ ctx: ProgramContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class AndContext: ProgramContext {
			open
			func program() -> [ProgramContext] {
				return getRuleContexts(ProgramContext.self)
			}
			open
			func program(_ i: Int) -> ProgramContext? {
				return getRuleContext(ProgramContext.self, i)
			}
			open
			func AND() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.AND.rawValue, 0)
			}
			open
			func NEWLINES() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.NEWLINES.rawValue, 0)
			}

		public
		init(_ ctx: ProgramContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class PipeContext: ProgramContext {
			open
			func program() -> [ProgramContext] {
				return getRuleContexts(ProgramContext.self)
			}
			open
			func program(_ i: Int) -> ProgramContext? {
				return getRuleContext(ProgramContext.self, i)
			}
			open
			func PIPE() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.PIPE.rawValue, 0)
			}
			open
			func NEWLINES() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.NEWLINES.rawValue, 0)
			}

		public
		init(_ ctx: ProgramContext) {
			super.init()
			copyFrom(ctx)
		}
	}
	public class SeqContext: ProgramContext {
			open
			func program() -> [ProgramContext] {
				return getRuleContexts(ProgramContext.self)
			}
			open
			func program(_ i: Int) -> ProgramContext? {
				return getRuleContext(ProgramContext.self, i)
			}
			open
			func SEMICOLON() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.SEMICOLON.rawValue, 0)
			}
			open
			func NEWLINES() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.NEWLINES.rawValue, 0)
			}

		public
		init(_ ctx: ProgramContext) {
			super.init()
			copyFrom(ctx)
		}
	}

	 public final  func program( ) throws -> ProgramContext   {
		return try program(0)
	}
	@discardableResult
	private func program(_ _p: Int) throws -> ProgramContext   {
		let _parentctx: ParserRuleContext? = _ctx
		let _parentState: Int = getState()
		var _localctx: ProgramContext
		_localctx = ProgramContext(_ctx, _parentState)
		var _prevctx: ProgramContext = _localctx
		let _startState: Int = 2
		try enterRecursionRule(_localctx, 2, AeroShellParser.RULE_program, _p)
		var _la: Int = 0
		defer {
	    		try! unrollRecursionContexts(_parentctx)
	    }
		do {
			var _alt: Int
			try enterOuterAlt(_localctx, 1)
			setState(26)
			try _errHandler.sync(self)
			switch (AeroShellParser.Tokens(rawValue: try _input.LA(1))!) {
			case .NOT:
				_localctx = NotContext(_localctx)
				_ctx = _localctx
				_prevctx = _localctx

				setState(15)
				try match(AeroShellParser.Tokens.NOT.rawValue)
				setState(16)
				try program(7)

				break

			case .LPAR:
				_localctx = ParensContext(_localctx)
				_ctx = _localctx
				_prevctx = _localctx
				setState(17)
				try match(AeroShellParser.Tokens.LPAR.rawValue)
				setState(18)
				try program(0)
				setState(19)
				try match(AeroShellParser.Tokens.RPAR.rawValue)

				break
			case .SINGLE_QUOTED_STRING:fallthrough
			case .LDQUOTE:fallthrough
			case .INTERPOLATION_START:fallthrough
			case .WORD:
				_localctx = ArgsContext(_localctx)
				_ctx = _localctx
				_prevctx = _localctx
				setState(22); 
				try _errHandler.sync(self)
				_alt = 1;
				repeat {
					switch (_alt) {
					case 1:
						setState(21)
						try arg()


						break
					default:
						throw ANTLRException.recognition(e: NoViableAltException(self))
					}
					setState(24); 
					try _errHandler.sync(self)
					_alt = try getInterpreter().adaptivePredict(_input,1,_ctx)
				} while (_alt != 2 && _alt !=  ATN.INVALID_ALT_NUMBER)

				break
			default:
				throw ANTLRException.recognition(e: NoViableAltException(self))
			}
			_ctx!.stop = try _input.LT(-1)
			setState(56)
			try _errHandler.sync(self)
			_alt = try getInterpreter().adaptivePredict(_input,8,_ctx)
			while (_alt != 2 && _alt != ATN.INVALID_ALT_NUMBER) {
				if ( _alt==1 ) {
					if _parseListeners != nil {
					   try triggerExitRuleEvent()
					}
					_prevctx = _localctx
					setState(54)
					try _errHandler.sync(self)
					switch(try getInterpreter().adaptivePredict(_input,7, _ctx)) {
					case 1:
						_localctx = PipeContext(  ProgramContext(_parentctx, _parentState))
						try pushNewRecursionContext(_localctx, _startState, AeroShellParser.RULE_program)
						setState(28)
						if (!(precpred(_ctx, 6))) {
						    throw ANTLRException.recognition(e:FailedPredicateException(self, "precpred(_ctx, 6)"))
						}
						setState(30)
						try _errHandler.sync(self)
						_la = try _input.LA(1)
						if (_la == AeroShellParser.Tokens.NEWLINES.rawValue) {
							setState(29)
							try match(AeroShellParser.Tokens.NEWLINES.rawValue)

						}

						setState(32)
						try match(AeroShellParser.Tokens.PIPE.rawValue)
						setState(33)
						try program(7)

						break
					case 2:
						_localctx = AndContext(  ProgramContext(_parentctx, _parentState))
						try pushNewRecursionContext(_localctx, _startState, AeroShellParser.RULE_program)
						setState(34)
						if (!(precpred(_ctx, 5))) {
						    throw ANTLRException.recognition(e:FailedPredicateException(self, "precpred(_ctx, 5)"))
						}
						setState(36)
						try _errHandler.sync(self)
						_la = try _input.LA(1)
						if (_la == AeroShellParser.Tokens.NEWLINES.rawValue) {
							setState(35)
							try match(AeroShellParser.Tokens.NEWLINES.rawValue)

						}

						setState(38)
						try match(AeroShellParser.Tokens.AND.rawValue)
						setState(39)
						try program(6)

						break
					case 3:
						_localctx = OrContext(  ProgramContext(_parentctx, _parentState))
						try pushNewRecursionContext(_localctx, _startState, AeroShellParser.RULE_program)
						setState(40)
						if (!(precpred(_ctx, 4))) {
						    throw ANTLRException.recognition(e:FailedPredicateException(self, "precpred(_ctx, 4)"))
						}
						setState(42)
						try _errHandler.sync(self)
						_la = try _input.LA(1)
						if (_la == AeroShellParser.Tokens.NEWLINES.rawValue) {
							setState(41)
							try match(AeroShellParser.Tokens.NEWLINES.rawValue)

						}

						setState(44)
						try match(AeroShellParser.Tokens.OR.rawValue)
						setState(45)
						try program(5)

						break
					case 4:
						_localctx = SeqContext(  ProgramContext(_parentctx, _parentState))
						try pushNewRecursionContext(_localctx, _startState, AeroShellParser.RULE_program)
						setState(46)
						if (!(precpred(_ctx, 3))) {
						    throw ANTLRException.recognition(e:FailedPredicateException(self, "precpred(_ctx, 3)"))
						}
						setState(47)
						_la = try _input.LA(1)
						if (!(_la == AeroShellParser.Tokens.SEMICOLON.rawValue || _la == AeroShellParser.Tokens.NEWLINES.rawValue)) {
						try _errHandler.recoverInline(self)
						}
						else {
							_errHandler.reportMatch(self)
							try consume()
						}
						setState(51)
						try _errHandler.sync(self)
						_alt = try getInterpreter().adaptivePredict(_input,6,_ctx)
						while (_alt != 1 && _alt != ATN.INVALID_ALT_NUMBER) {
							if ( _alt==1+1 ) {
								setState(48)
								try program(0)

						 
							}
							setState(53)
							try _errHandler.sync(self)
							_alt = try getInterpreter().adaptivePredict(_input,6,_ctx)
						}

						break
					default: break
					}
			 
				}
				setState(58)
				try _errHandler.sync(self)
				_alt = try getInterpreter().adaptivePredict(_input,8,_ctx)
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
			return AeroShellParser.RULE_arg
		}
	}
	public class WordContext: ArgContext {
			open
			func WORD() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.WORD.rawValue, 0)
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
				return getToken(AeroShellParser.Tokens.INTERPOLATION_START.rawValue, 0)
			}
			open
			func program() -> ProgramContext? {
				return getRuleContext(ProgramContext.self, 0)
			}
			open
			func RPAR() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.RPAR.rawValue, 0)
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
				return getToken(AeroShellParser.Tokens.SINGLE_QUOTED_STRING.rawValue, 0)
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
				return getToken(AeroShellParser.Tokens.LDQUOTE.rawValue, 0)
			}
			open
			func RDQUOTE() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.RDQUOTE.rawValue, 0)
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
		try enterRule(_localctx, 4, AeroShellParser.RULE_arg)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	setState(73)
		 	try _errHandler.sync(self)
		 	switch (AeroShellParser.Tokens(rawValue: try _input.LA(1))!) {
		 	case .WORD:
		 		_localctx =  WordContext(_localctx);
		 		try enterOuterAlt(_localctx, 1)
		 		setState(59)
		 		try match(AeroShellParser.Tokens.WORD.rawValue)

		 		break

		 	case .LDQUOTE:
		 		_localctx =  DQuotedStringContext(_localctx);
		 		try enterOuterAlt(_localctx, 2)
		 		setState(60)
		 		try match(AeroShellParser.Tokens.LDQUOTE.rawValue)
		 		setState(64)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 		while (((Int64(_la) & ~0x3f) == 0 && ((Int64(1) << _la) & 917504) != 0)) {
		 			setState(61)
		 			try dStringFragment()


		 			setState(66)
		 			try _errHandler.sync(self)
		 			_la = try _input.LA(1)
		 		}
		 		setState(67)
		 		try match(AeroShellParser.Tokens.RDQUOTE.rawValue)

		 		break

		 	case .INTERPOLATION_START:
		 		_localctx =  SubstitutionContext(_localctx);
		 		try enterOuterAlt(_localctx, 3)
		 		setState(68)
		 		try match(AeroShellParser.Tokens.INTERPOLATION_START.rawValue)
		 		setState(69)
		 		try program(0)
		 		setState(70)
		 		try match(AeroShellParser.Tokens.RPAR.rawValue)

		 		break

		 	case .SINGLE_QUOTED_STRING:
		 		_localctx =  SQuotedStringContext(_localctx);
		 		try enterOuterAlt(_localctx, 4)
		 		setState(72)
		 		try match(AeroShellParser.Tokens.SINGLE_QUOTED_STRING.rawValue)

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

	public class DStringFragmentContext: ParserRuleContext {
		override open
		func getRuleIndex() -> Int {
			return AeroShellParser.RULE_dStringFragment
		}
	}
	public class InterpolationContext: DStringFragmentContext {
			open
			func INTERPOLATION_START_IN_DSTRING() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.INTERPOLATION_START_IN_DSTRING.rawValue, 0)
			}
			open
			func program() -> ProgramContext? {
				return getRuleContext(ProgramContext.self, 0)
			}
			open
			func RPAR() -> TerminalNode? {
				return getToken(AeroShellParser.Tokens.RPAR.rawValue, 0)
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
				return getToken(AeroShellParser.Tokens.ESCAPE_SEQUENCE.rawValue, 0)
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
				return getToken(AeroShellParser.Tokens.TEXT.rawValue, 0)
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
		try enterRule(_localctx, 6, AeroShellParser.RULE_dStringFragment)
		defer {
	    		try! exitRule()
	    }
		do {
		 	setState(81)
		 	try _errHandler.sync(self)
		 	switch (AeroShellParser.Tokens(rawValue: try _input.LA(1))!) {
		 	case .TEXT:
		 		_localctx =  TextContext(_localctx);
		 		try enterOuterAlt(_localctx, 1)
		 		setState(75)
		 		try match(AeroShellParser.Tokens.TEXT.rawValue)

		 		break

		 	case .ESCAPE_SEQUENCE:
		 		_localctx =  EscapeSequenceContext(_localctx);
		 		try enterOuterAlt(_localctx, 2)
		 		setState(76)
		 		try match(AeroShellParser.Tokens.ESCAPE_SEQUENCE.rawValue)

		 		break

		 	case .INTERPOLATION_START_IN_DSTRING:
		 		_localctx =  InterpolationContext(_localctx);
		 		try enterOuterAlt(_localctx, 3)
		 		setState(77)
		 		try match(AeroShellParser.Tokens.INTERPOLATION_START_IN_DSTRING.rawValue)
		 		setState(78)
		 		try program(0)
		 		setState(79)
		 		try match(AeroShellParser.Tokens.RPAR.rawValue)

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

	override open
	func sempred(_ _localctx: RuleContext?, _ ruleIndex: Int,  _ predIndex: Int)throws -> Bool {
		switch (ruleIndex) {
		case  1:
			return try program_sempred(_localctx?.castdown(ProgramContext.self), predIndex)
	    default: return true
		}
	}
	private func program_sempred(_ _localctx: ProgramContext!,  _ predIndex: Int) throws -> Bool {
		switch (predIndex) {
		    case 0:return precpred(_ctx, 6)
		    case 1:return precpred(_ctx, 5)
		    case 2:return precpred(_ctx, 4)
		    case 3:return precpred(_ctx, 3)
		    default: return true
		}
	}

	static let _serializedATN:[Int] = [
		4,1,20,84,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,1,0,1,0,1,0,1,0,3,0,13,8,0,1,
		1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,4,1,23,8,1,11,1,12,1,24,3,1,27,8,1,1,1,1,
		1,3,1,31,8,1,1,1,1,1,1,1,1,1,3,1,37,8,1,1,1,1,1,1,1,1,1,3,1,43,8,1,1,1,
		1,1,1,1,1,1,1,1,5,1,50,8,1,10,1,12,1,53,9,1,5,1,55,8,1,10,1,12,1,58,9,
		1,1,2,1,2,1,2,5,2,63,8,2,10,2,12,2,66,9,2,1,2,1,2,1,2,1,2,1,2,1,2,3,2,
		74,8,2,1,3,1,3,1,3,1,3,1,3,1,3,3,3,82,8,3,1,3,1,51,1,2,4,0,2,4,6,0,1,1,
		0,12,13,97,0,12,1,0,0,0,2,26,1,0,0,0,4,73,1,0,0,0,6,81,1,0,0,0,8,9,3,2,
		1,0,9,10,5,0,0,1,10,13,1,0,0,0,11,13,5,0,0,1,12,8,1,0,0,0,12,11,1,0,0,
		0,13,1,1,0,0,0,14,15,6,1,-1,0,15,16,5,11,0,0,16,27,3,2,1,7,17,18,5,4,0,
		0,18,19,3,2,1,0,19,20,5,6,0,0,20,27,1,0,0,0,21,23,3,4,2,0,22,21,1,0,0,
		0,23,24,1,0,0,0,24,22,1,0,0,0,24,25,1,0,0,0,25,27,1,0,0,0,26,14,1,0,0,
		0,26,17,1,0,0,0,26,22,1,0,0,0,27,56,1,0,0,0,28,30,10,6,0,0,29,31,5,13,
		0,0,30,29,1,0,0,0,30,31,1,0,0,0,31,32,1,0,0,0,32,33,5,9,0,0,33,55,3,2,
		1,7,34,36,10,5,0,0,35,37,5,13,0,0,36,35,1,0,0,0,36,37,1,0,0,0,37,38,1,
		0,0,0,38,39,5,8,0,0,39,55,3,2,1,6,40,42,10,4,0,0,41,43,5,13,0,0,42,41,
		1,0,0,0,42,43,1,0,0,0,43,44,1,0,0,0,44,45,5,10,0,0,45,55,3,2,1,5,46,47,
		10,3,0,0,47,51,7,0,0,0,48,50,3,2,1,0,49,48,1,0,0,0,50,53,1,0,0,0,51,52,
		1,0,0,0,51,49,1,0,0,0,52,55,1,0,0,0,53,51,1,0,0,0,54,28,1,0,0,0,54,34,
		1,0,0,0,54,40,1,0,0,0,54,46,1,0,0,0,55,58,1,0,0,0,56,54,1,0,0,0,56,57,
		1,0,0,0,57,3,1,0,0,0,58,56,1,0,0,0,59,74,5,7,0,0,60,64,5,3,0,0,61,63,3,
		6,3,0,62,61,1,0,0,0,63,66,1,0,0,0,64,62,1,0,0,0,64,65,1,0,0,0,65,67,1,
		0,0,0,66,64,1,0,0,0,67,74,5,20,0,0,68,69,5,5,0,0,69,70,3,2,1,0,70,71,5,
		6,0,0,71,74,1,0,0,0,72,74,5,2,0,0,73,59,1,0,0,0,73,60,1,0,0,0,73,68,1,
		0,0,0,73,72,1,0,0,0,74,5,1,0,0,0,75,82,5,17,0,0,76,82,5,19,0,0,77,78,5,
		18,0,0,78,79,3,2,1,0,79,80,5,6,0,0,80,82,1,0,0,0,81,75,1,0,0,0,81,76,1,
		0,0,0,81,77,1,0,0,0,82,7,1,0,0,0,12,12,24,26,30,36,42,51,54,56,64,73,81
	]

	public
	static let _ATN = try! ATNDeserializer().deserialize(_serializedATN)
}