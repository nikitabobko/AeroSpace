import Foundation

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
        let result = raw.compactMap {
            $0.value
        }
        raw = result.map { Weak(value: $0) }
        return result
    }
}
