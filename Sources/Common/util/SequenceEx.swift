import AppKit

public extension Sequence {
    func filterNotNil<Unwrapped>() -> [Unwrapped] where Element == Unwrapped? {
        compactMap { $0 }
    }

    func filterIsInstance<R>(of _: R.Type) -> [R] {
        var result: [R] = []
        for elem in self {
            if let elemR = elem as? R {
                result.append(elemR)
            }
        }
        return result
    }

    var first: Element? {
        var iter = makeIterator()
        return iter.next()
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

    func mapAllOrFailures<T, E>(_ transform: (Self.Element) -> Result<T, E>) -> Result<[T], [E]> {
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

    @inlinable func minByOrDie(_ selector: (Self.Element) -> some Comparable) -> Self.Element {
        minBy(selector) ?? dieT("Empty sequence")
    }

    @inlinable func minBy(_ selector: (Self.Element) -> some Comparable) -> Self.Element? {
        self.min(by: { a, b in selector(a) < selector(b) })
    }

    @inlinable func maxByOrDie(_ selector: (Self.Element) -> some Comparable) -> Self.Element? {
        self.maxBy(selector) ?? dieT("Empty sequence")
    }

    @inlinable func maxBy(_ selector: (Self.Element) -> some Comparable) -> Self.Element? {
        self.max(by: { a, b in selector(a) < selector(b) })
    }

    @inlinable func sortedBy(_ selector: (Self.Element) -> some Comparable) -> [Self.Element] {
        sorted(by: { a, b in selector(a) < selector(b) })
    }

    @inlinable func sortedBy(_ selectors: [(Self.Element) -> some Comparable]) -> [Self.Element] {
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

    func sumOf(_ selector: (Self.Element) -> Double) -> Double {
        var result: Double = 0
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

public extension Sequence where Self.Element: Comparable {
    func minOrDie() -> Self.Element {
        self.min() ?? dieT("Empty sequence")
    }

    func maxOrDie() -> Self.Element {
        self.max() ?? dieT("Empty sequence")
    }
}

public extension Sequence where Element: Hashable {
    func toSet() -> Set<Element> { Set(self) }
}
