import AppKit

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

    public var first: Element? {
        var iter = makeIterator()
        return iter.next()
    }

    public func mapAllOrFailure<T, E>(_ transform: (Self.Element) -> Result<T, E>) -> Result<[T], E> {
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

    public func mapAllOrFailures<T, E>(_ transform: (Self.Element) -> Result<T, E>) -> Result<[T], [E]> {
        var result: [T] = []
        var errors: [E] = []
        for element in self {
            switch transform(element) {
                case .success(let element): result.append(element)
                case .failure(let error): errors.append(error)
            }
        }
        return errors.isEmpty ? .success(result) : .failure(errors)
    }

    @inlinable public func minByOrDie(_ selector: (Self.Element) -> some Comparable) -> Self.Element {
        minBy(selector) ?? dieT("Empty sequence")
    }

    @inlinable public func minBy(_ selector: (Self.Element) -> some Comparable) -> Self.Element? {
        self.min(by: { a, b in selector(a) < selector(b) })
    }

    @inlinable public func maxByOrDie(_ selector: (Self.Element) -> some Comparable) -> Self.Element? {
        self.maxBy(selector) ?? dieT("Empty sequence")
    }

    @inlinable public func maxBy(_ selector: (Self.Element) -> some Comparable) -> Self.Element? {
        self.max(by: { a, b in selector(a) < selector(b) })
    }

    @inlinable public func sortedBy(_ selector: (Self.Element) -> some Comparable) -> [Self.Element] {
        sorted(by: { a, b in selector(a) < selector(b) })
    }

    @inlinable public func sortedBy(_ selectors: [(Self.Element) -> some Comparable]) -> [Self.Element] {
        sorted(by: { a, b in
            for selector in selectors {
                let a = selector(a)
                let b = selector(b)
                if a < b { return true }
                if a > b { return false }
            }
            return false
        })
    }

    public func sumOfDouble(_ selector: (Self.Element) -> Double) -> Double {
        var result: Double = 0
        for elem in self {
            result += selector(elem)
        }
        return result
    }

    public func grouped<Group>(by criterion: (_ transforming: Element) -> Group) -> [Group: [Element]] {
        Dictionary(grouping: self, by: criterion)
    }

    public var withIndex: [(index: Int, value: Element)] {
        var index = -1
        return map {
            index += 1
            return (index, $0)
        }
    }
}

extension Sequence where Self.Element: Comparable {
    public func minOrDie() -> Self.Element {
        self.min() ?? dieT("Empty sequence")
    }

    public func maxOrDie() -> Self.Element {
        self.max() ?? dieT("Empty sequence")
    }
}

extension Sequence where Element: Hashable {
    public func toSet() -> Set<Element> { Set(self) }
}
