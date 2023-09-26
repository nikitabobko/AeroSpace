/// Stack with most recently element on top
class MruStack<T: Equatable>: Sequence {
    typealias Iterator = MruStackIterator
    typealias Element = T

    private var mruNode: Node<T>? = nil

    func makeIterator() -> MruStackIterator<T> {
        MruStackIterator(mruNode)
    }

    var mostRecent: T? { mruNode?.value }

    func pushOrRaise(_ value: T) {
        remove(value)
        mruNode = Node(value, mruNode)
    }

    @discardableResult
    func remove(_ value: T) -> Bool {
        var prev: Node<T>? = nil
        var current = mruNode
        while current != nil {
            if current?.value == value {
                if let prev {
                    prev.next = current?.next
                } else {
                    mruNode = nil
                }
                current?.next = nil
                return true
            }
            prev = current
            current = current?.next
        }
        return false
    }
}

extension MruStack where T: Hashable {
    var mruIndexMap: [T: Int] {
        var result: [T: Int] = [:]
        for indexed in self.lazy.withIndex {
            result[indexed.value] = indexed.index
        }
        return result
    }
}

struct MruStackIterator<T: Equatable>: IteratorProtocol {
    typealias Element = T
    private var current: Node<T>?

    fileprivate init(_ current: Node<T>?) {
        self.current = current
    }

    mutating func next() -> T? {
        let result = current?.value
        current = current?.next
        return result
    }
}

private class Node<T: Equatable> {
    var next: Node<T>? = nil
    let value: T

    init(_ value: T, _ next: Node<T>?) {
        self.value = value
        self.next = next
    }

    init(_ value: T) {
        self.value = value
    }
}
