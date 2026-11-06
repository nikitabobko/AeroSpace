/// Path to a tiling container in the workspace tree.
/// `/` is the root tiling container of the workspace, `/0/1` is the second child of the first child of the root container
public struct ContainerPath: Equatable, Sendable, CustomStringConvertible {
    public let indices: [Int]

    public init(_ indices: [Int]) {
        self.indices = indices
    }

    public var description: String { "/" + indices.lazy.map { String($0) }.joined(separator: "/") }
}
