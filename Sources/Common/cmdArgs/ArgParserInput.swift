public struct ArgParserInput: ArgParserInputProtocol {
    let index: Int
    let args: StrArrSlice

    var arg: String { args[index] }
}

protocol ArgParserInputProtocol {
    var index: Int { get }
    var args: StrArrSlice { get }
}

extension ArgParserInputProtocol {
    func getOrNil(relativeIndex i: Int) -> String? { args.getOrNil(atIndex: index + i) }

    func nonFlagArgs() -> ArrSlice<String> {
        var i = index
        while args.indices.contains(i) && !args[i].starts(with: "-") {
            i += 1
        }
        return args.slice(index ..< i).orDie()
    }

    func nonFlagArgOrNil() -> String? {
        args.getOrNil(atIndex: index)?.takeIf { !$0.starts(with: "-") }
    }
}
