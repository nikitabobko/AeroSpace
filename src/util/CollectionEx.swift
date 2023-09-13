extension Collection {
    func singleOrNil() -> Element? {
        count == 1 ? first : nil
    }
}