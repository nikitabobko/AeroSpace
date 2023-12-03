extension Sequence {
    public func filterNotNil<Unwrapped>() -> [Unwrapped] where Element == Unwrapped? {
        compactMap { $0 }
    }

    public func filterIsInstance<R>(of _: R.Type) -> [R] {
        var result: [R] = []
        for elem in self {
            if let elemR = elem as? R {
                result.append(elemR)
            }
        }
        return result
    }

    func mapAllOrFailure<T, E>(_ transform: (Self.Element) -> Result<T, E>) -> Result<[T], E> {
        var result: [T] = []
        for element in self {
            switch transform(element) {
            case .success(let element):
                result.append(element)
            case .failure(let errors):
                return .failure(errors)
            }
        }
        return .success(result)
    }

    @inlinable public func minByOrThrow<S: Comparable>(_ selector: (Self.Element) -> S) -> Self.Element {
        minBy(selector) ?? errorT("Empty sequence")
    }

    @inlinable public func minBy<S : Comparable>(_ selector: (Self.Element) -> S) -> Self.Element? {
        self.min(by: { a, b in selector(a) < selector(b) })
    }

    @inlinable public func maxByOrThrow<S : Comparable>(_ selector: (Self.Element) -> S) -> Self.Element? {
        self.maxBy(selector) ?? errorT("Empty sequence")
    }

    @inlinable public func maxBy<S : Comparable>(_ selector: (Self.Element) -> S) -> Self.Element? {
        self.max(by: { a, b in selector(a) < selector(b) })
    }

    @inlinable public func sortedBy<S : Comparable>(_ selector: (Self.Element) -> S) -> [Self.Element] {
        sorted(by: { a, b in selector(a) < selector(b) })
    }

    func sumOf(_ selector: (Self.Element) -> CGFloat) -> CGFloat {
        var result: CGFloat = 0
        for elem in self {
            result += selector(elem)
        }
        return result
    }

    func grouped<Group>(by criterion: (_ transforming: Element) -> Group) -> [Group: [Element]] {
        Dictionary(grouping: self, by: criterion)
    }

    var withIndex: [(index: Int, value: Element)] {
        var index = -1
        return map {
            index += 1
            return (index, $0)
        }
    }
}

extension Sequence where Self.Element: Comparable {
    public func minOrThrow() -> Self.Element {
        self.min() ?? errorT("Empty sequence")
    }

    public func maxOrThrow() -> Self.Element {
        self.max() ?? errorT("Empty sequence")
    }
}

extension Sequence where Element: Hashable {
    func toSet() -> Set<Element> { Set(self) }
}
