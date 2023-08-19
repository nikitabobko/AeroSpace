import Foundation

// todo unused?
struct Weak<T: AnyObject> {
    weak var value: T?

    init(_ value: T?) {
        self.value = value
    }
}

struct WeakArray<T: AnyObject> {
    var raw: [Weak<T>] = []

    init() {
    }

    init(_ raw: [Weak<T>]) {
        self.raw = raw
    }

    mutating func deref() -> [T] {
        let result = raw.compactMap { $0.value }
        raw = result.map { Weak($0) }
        return result
    }
}

extension Weak: Hashable, Equatable where T: Hashable, T: Equatable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }

    static func ==(lhs: Weak<T>, rhs: Weak<T>) -> Bool {
        lhs.value == rhs.value
    }
}

// todo replace usages with WeakArray? Maybe it's enough for the usages
struct WeakSet<T> where T: AnyObject, T: Hashable {
    var raw: Set<Weak<T>> = []

    init() {
    }

    init(_ raw: Set<Weak<T>>) {
        self.raw = raw
    }

    mutating func deref() -> Set<T> {
        let result: Set<T> = raw.compactMap { $0.value }.toSet()
        raw = result.map { Weak($0) }.toSet()
        return result
    }
}
