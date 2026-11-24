public final class MainActorRef<T>: Sendable {
    @MainActor public var value: T
    @MainActor public init(_ value: T) { self.value = value }
}
