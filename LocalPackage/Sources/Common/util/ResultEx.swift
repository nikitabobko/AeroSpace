public extension Result {
    func getOrNil(appendErrorTo errors: inout [Failure]) -> Success? {
        switch self {
        case .success(let success):
            return success
        case .failure(let error):
            errors += [error]
            return nil
        }
    }

    func getOrNil() -> Success? {
        switch self {
        case .success(let success):
            return success
        case .failure:
            return nil
        }
    }

    func getOrNils() -> (Success?, Failure?) {
        switch self {
        case .success(let success):
            return (success, nil)
        case .failure(let failure):
            return (nil, failure)
        }
    }

    var errorOrNil: Failure? {
        switch self {
        case .success:
            return nil
        case .failure(let f):
            return f
        }
    }
}

public extension Result where Failure == AeroError {
    @discardableResult
    func getOrThrow(_ msgPrefix: String = "") -> Success {
        switch self {
        case .success(let suc):
            return suc
        case .failure(let e):
            e.throwIt(msgPrefix)
        }
    }
}
