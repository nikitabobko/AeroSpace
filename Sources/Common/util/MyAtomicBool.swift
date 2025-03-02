import Foundation

/// Alternative 1. In macOS 15, it's possible to use `Atomic` from `Synchronization` module
/// Alternative 2. https://github.com/apple/swift-atomics/tree/main but I don't want to add one more dependency just for
///                AtomicBool
/// MyAtomicBool works on macOS 13+
public final class MyAtomicBool: Sendable {
    private nonisolated(unsafe) var val: Int32 = 0

    public init(_ initial: Bool) { set(initial) }

    public func set(_ value: Bool) {
        while !OSAtomicCompareAndSwapInt(val, value ? 1 : 0, &val) {}
    }

    public func get() -> Bool { val != 0 }
}
