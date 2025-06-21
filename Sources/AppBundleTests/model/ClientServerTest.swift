@testable import AppBundle
import Common
import XCTest

final class ClientServerTest: XCTestCase {
    func testClientRequestJsonCompatibility_decoding() {
        let data = """
            { "command": "deprecated", "args": ["foo", "bar"], "stdin": "stdin" }
            """.data(using: .utf8)!
        assertSucc(ClientRequest.decodeJson(data))
    }

    func testClientRequestJsonCompatibility_decoding_future() {
        let data = """
            { "args": ["foo", "bar"], "stdin": "stdin" }
            """.data(using: .utf8)!
        assertSucc(ClientRequest.decodeJson(data))
    }

    func testClientRequestJsonCompatibility_encoding() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try! encoder.encode(ClientRequest(args: ["args"], stdin: "stdin"))
        let str = String.init(data: data, encoding: .utf8)!
        assertEquals(str, """
            {"args":["args"],"command":"args","stdin":"stdin"}
            """)
    }
}
