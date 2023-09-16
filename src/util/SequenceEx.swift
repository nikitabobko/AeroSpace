import Foundation

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

    var withIndex: [Indexed<Element>] {
        var index = -1
        return map {
            index += 1
            return Indexed(index: index, value: $0)
        }
    }
}

struct Indexed<T> {
    let index: Int
    let value: T
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
