import Common

indirect enum Shell<T> {
    case empty
    case cmd(T)

    // Listed in precedence order
    case pipe([Shell<T>])
    case and([Shell<T>])
    case or([Shell<T>])
    case seq([Shell<T>])

    static func newCompound(_ elems: [Self], _ constructor: ([Self]) -> Self) -> Self {
        switch elems.singleOrNil() {
            case let single?: single
            case nil: constructor(elems)
        }
    }
}

extension Shell: Equatable where T: Equatable {}
