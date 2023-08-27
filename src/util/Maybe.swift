/// Yes, I know that Swift has its own Optional.
/// I introduce my own because Swift has problems with Optional<Optional<T>>
enum Maybe<T> {
    case Nothing
    case Just(T)
}

extension Maybe {
    var valueOrNil: T? {
        switch self {
        case .Nothing:
            return nil
        case .Just(let value):
            return value
        }
    }

    static func from(_ value: T?) -> Maybe<T> {
        if let value {
            return Maybe.Just(value)
        } else {
            return Maybe.Nothing
        }
    }
}
