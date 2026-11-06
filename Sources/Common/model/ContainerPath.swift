/// Path to a tiling container in the workspace tree.
/// `/` is the root tiling container of the workspace, `/0/1` is the second child of the first child of the root container
public struct ContainerPath: Equatable, Sendable, CustomStringConvertible {
    public let indices: [Int]

    public init(_ indices: [Int]) {
        self.indices = indices
    }

    public static func parse(_ raw: String) -> ResOrStr<ContainerPath> {
        let expectedFormat = "Expected format: '/' or '/<index>/<index>/...'. For example: '/0/1'"
        if !raw.starts(with: "/") {
            return .failure("Container path must start with '/'. \(expectedFormat)")
        }
        if raw == "/" {
            return .success(ContainerPath([]))
        }
        var indices: [Int] = []
        for segment in raw.dropFirst().split(separator: "/", omittingEmptySubsequences: false) {
            guard let index = Int(segment), index >= 0 else {
                return .failure("Can't parse container path \(raw.singleQuoted). \(expectedFormat)")
            }
            indices.append(index)
        }
        return .success(ContainerPath(indices))
    }

    public var description: String { "/" + indices.lazy.map { String($0) }.joined(separator: "/") }
}
