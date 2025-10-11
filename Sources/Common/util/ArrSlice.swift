import Foundation

public typealias StrArrSlice = ArrSlice<String>

// The default ArraySlice that is shiped with Swift stdlib is wrong (my subjective opinion). Their subscript is not zero-based.
// Their Slice is not properly encapsulated
//
// That's why we declare our own ArrSlice
public struct ArrSlice<Element>: Sequence, AeroAny, ExpressibleByArrayLiteral, RandomAccessCollection {
    fileprivate let backing: [Element]
    fileprivate let offsetInBacking: Int
    /*conforms*/ public let count: Int

    public init(arrayLiteral elements: Element...) {
        self.init(elements, 0 ..< elements.count)
    }

    private init(_ backing: [Element], _ range: Range<Int>) {
        self.backing = range.isEmpty ? [] : backing
        self.offsetInBacking = range.isEmpty ? 0 : range.startIndex
        self.count = range.count
    }

    public static func new(_ backing: [Element], _ range: Range<Int>) -> Self? {
        range.isSubRange(of: backing.indices) ? .init(backing, range) : nil
    }

    public subscript(_ zeroBasedIndex: Int) -> Element {
        check(indices.contains(zeroBasedIndex))
        return backing[zeroBasedIndex + offsetInBacking]
    }

    /*conforms*/ public var startIndex: Int { 0 }
    /*conforms*/ public var endIndex: Int { count }
    /*conforms*/ public func index(after i: Int) -> Int { i + 1 }
    public func getOrNil(atIndex index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
    /*conforms*/ public var indices: Range<Int> { 0 ..< count }
    public func makeIterator() -> some IteratorProtocol<Element> { ArrSliceIterator(backing: self) }
    public func toArray() -> [Element] { Array(self) }
}

private struct ArrSliceIterator<Element>: IteratorProtocol {
    fileprivate let backing: ArrSlice<Element>
    fileprivate var index: Int = 0

    mutating func next() -> Element? {
        if index < backing.count {
            let value = backing[index]
            index += 1
            return value
        } else {
            return nil
        }
    }
}

extension ArrSlice: Sendable where Element: Sendable {}

extension ArrSlice: Equatable where Element: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs.count != rhs.count { return false }
        for i in lhs.indices {
            if lhs[i] != rhs[i] { return false }
        }
        return true
    }
}

extension Array {
    public var slice: ArrSlice<Element> { slice(0 ..< count).orDie() }
    public func slice(_ range: PartialRangeFrom<Int>) -> ArrSlice<Element>? { slice(range.lowerBound ..< count) }
    public func slice(_ range: PartialRangeUpTo<Int>) -> ArrSlice<Element>? { slice(0 ..< range.upperBound) }

    public func slice(_ range: Range<Int>) -> ArrSlice<Element>? { .new(self, range) }
}

extension Range<Int> {
    func shift(by value: Int) -> Range<Int> { value + startIndex ..< value + endIndex }
    func isSubRange(of outer: Range<Int>) -> Bool {
        outer.lowerBound <= self.lowerBound && self.upperBound <= outer.upperBound
    }
}

extension ArrSlice {
    public func slice(_ range: PartialRangeFrom<Int>) -> ArrSlice<Element>? { slice(range.lowerBound ..< count) }
    public func slice(_ range: PartialRangeUpTo<Int>) -> ArrSlice<Element>? { slice(0 ..< range.upperBound) }

    public func slice(_ range: Range<Int>) -> ArrSlice<Element>? {
        range.isSubRange(of: indices) ? .new(self.backing, range.shift(by: self.offsetInBacking)) : nil
    }
}
