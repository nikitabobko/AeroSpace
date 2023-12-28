public typealias Parsed<T> = Result<T, String>
extension String: Error {}

public extension String {
    func trim() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
