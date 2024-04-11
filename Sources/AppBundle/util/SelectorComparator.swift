import AppKit
import Common

struct SelectorComparator<T, S: Comparable>: SortComparator, Hashable {
    typealias Compared = T
    var order: SortOrder = .forward
    let selector: (T) -> S

    func compare(_ lhs: T, _ rhs: T) -> ComparisonResult {
        let a = selector(lhs)
        let b = selector(rhs)
        if a < b {
            return .orderedAscending
        } else if a > b {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    static func == (lhs: SelectorComparator<T, S>, rhs: SelectorComparator<T, S>) -> Bool {
        error("Not supported")
    }
    func hash(into hasher: inout Hasher) {
        error("Not supported")
    }
}
