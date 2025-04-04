import Foundation

/// Alternative 1. In macOS 15, it's possible to use `Atomic<Bool>` from `Synchronization` module
/// Alternative 2. https://github.com/apple/swift-atomics/tree/main but I don't want to add one more dependency just for
///                AtomicBool
/// OneTimeLatch works on macOS 13+
public final class OneTimeLatch: Sendable {
    private nonisolated(unsafe) var val: Int32 = 0
    public init() {}

    public func trigger() {
        while !isTriggered {
            OSAtomicCompareAndSwapInt(0, 1, &val)
        }
    }

    public var isTriggered: Bool { val == 1 }
}
