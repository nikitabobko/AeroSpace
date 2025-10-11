public typealias SubArgParserFun<K> = @Sendable (/*arg*/ String, /*nextArgs*/ inout [String]) -> Parsed<K>
public protocol SubArgParserProtocol<T>: Sendable, AeroAny {
    associatedtype K
    associatedtype T where T: ConvenienceCopyable
    var keyPath: SendableWritableKeyPath<T, K> { get }
    var parse: SubArgParserFun<K> { get }
}
public struct SubArgParser<T: ConvenienceCopyable, K>: SubArgParserProtocol {
    public let keyPath: SendableWritableKeyPath<T, K>
    public let parse: SubArgParserFun<K>

    public init(
        _ keyPath: SendableWritableKeyPath<T, K>,
        _ parse: @escaping SubArgParserFun<K>,
    ) {
        self.keyPath = keyPath
        self.parse = parse
    }
}

func upcastSubArgParserFun<T>(_ fun: @escaping SubArgParserFun<T>) -> SubArgParserFun<T?> { { fun($0, &$1).map { $0 } } }
