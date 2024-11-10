extension [String] {
    mutating func next() -> String {
        nextOrNil() ?? errorT("args is empty")
    }

    mutating func nextNonFlagOrNil() -> String? {
        first?.starts(with: "-") == true ? nil : nextOrNil()
    }

    mutating func nextNonFullFlagOrNil() -> String? {
        first?.starts(with: "--") == true ? nil : nextOrNil()
    }

    mutating func allNextNonFlagArgs() -> [String] {
        var args: [String] = []
        while let nextArg = nextNonFlagOrNil() {
            args.append(nextArg)
        }
        return args
    }

    private mutating func nextOrNil() -> String? {
        let result = first
        self = Array(dropFirst())
        return result
    }
}
