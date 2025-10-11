extension [String] { // todo drop
    mutating func next() -> String {
        nextOrNil() ?? dieT("args is empty")
    }

    mutating func nextNonFlagOrNil() -> String? {
        first?.starts(with: "-") == true ? nil : nextOrNil()
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
