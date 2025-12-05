public enum Either<L, R> {
    case left(L)
    case right(R)

    public var leftOrNil: L? {
        switch self {
            case .left(let l): l
            case .right: nil
        }
    }
}
