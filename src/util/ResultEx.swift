extension Result {
    func getOrNil(appendErrorTo errors: inout [Failure]) -> Success? {
        switch self {
        case .success(let success):
            return success
        case .failure(let error):
            errors += [error]
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
}
