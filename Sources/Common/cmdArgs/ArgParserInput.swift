struct PosArgParserInput: ArgParserInput {
    /*conforms*/ let index: Int
    /*conforms*/ let args: StrArrSlice
    var sawDashDash: Bool

    var arg: String { args[index] }
}

struct SubArgParserInput: ArgParserInput {
    let superArg: String
    /*conforms*/ let index: Int
    /*conforms*/ let args: StrArrSlice

    var argOrNil: String? { args.getOrNil(atIndex: index) }
}

protocol ArgParserInput {
    var index: Int { get }
    var args: StrArrSlice { get }
}

extension ArgParserInput {
    func getOrNil(relativeIndex i: Int) -> String? { args.getOrNil(atIndex: index + i) }

    func nonFlagArgs() -> ArrSlice<String> {
        var i = index
        while args.indices.contains(i) && !args[i].isCliDashFlag {
            i += 1
        }
        return args.slice(index ..< i).orDie()
    }

    func nonFlagArgOrNil() -> String? {
        args.getOrNil(atIndex: index)?.takeIf { !$0.isCliDashFlag }
    }
}

extension String {
    public var isCliDashFlag: Bool {
        self != "--" && self != "-" && starts(with: "-")
    }
}
