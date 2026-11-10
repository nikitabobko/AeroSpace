extension AsyncStream {
    public func first() async -> Element? {
        for await element in self { return element }
        return nil
    }
}
