@testable import AppBundle
import Common
import XCTest

final class ClientServerTest: XCTestCase {
    func testClientRequestJsonV1_decoding() {
        let data = """
            { "command": "deprecated", "args": ["foo", "bar"], "stdin": "stdin" }
            """.data(using: .utf8)!
        let expected = ClientRequest(args: ["foo", "bar"], stdin: "stdin", windowId: nil, workspace: nil)
            .copy(\.windowId, nil)
            .copy(\.workspace, nil)
        assertSucc(ClientRequest.decodeJson(data), expected)
    }

    func testClientRequestJsonV2_decoding() {
        let data = """
            { "args": ["foo", "bar"], "stdin": "stdin" }
            """.data(using: .utf8)!
        let expected = ClientRequest(args: ["foo", "bar"], stdin: "stdin", windowId: nil, workspace: nil)
            .copy(\.windowId, nil)
            .copy(\.workspace, nil)
        assertSucc(ClientRequest.decodeJson(data), expected)
    }

    func testClientRequestJsonV3_decoding() {
        let data = """
            { "args": ["foo", "bar"], "stdin": "stdin", "windowId": null, "workspace": null }
            """.data(using: .utf8)!
        let expected = ClientRequest(args: ["foo", "bar"], stdin: "stdin", windowId: nil, workspace: nil)
        assertSucc(ClientRequest.decodeJson(data), expected)
    }

    func testClientRequestJsonV3_decoding2() {
        let data = """
            { "args": ["foo", "bar"], "stdin": "stdin", "windowId": 1, "workspace": "foo" }
            """.data(using: .utf8)!
        let expected = ClientRequest(args: ["foo", "bar"], stdin: "stdin", windowId: 1, workspace: "foo")
        assertSucc(ClientRequest.decodeJson(data), expected)
    }

    func testClientRequestJsonV9999_decoding() {
        let data = """
            { "args": ["foo", "bar"], "stdin": "stdin", "yet another future field": 1 }
            """.data(using: .utf8)!
        assertSucc(ClientRequest.decodeJson(data))
    }

    func testClientRequestJsonCompatibility_encoding() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let testData = [
            (ClientRequest(args: ["args"], stdin: "stdin", windowId: 0, workspace: "foo"), """
                {"args":["args"],"stdin":"stdin","windowId":0,"workspace":"foo"}
                """),
            (ClientRequest(args: ["args"], stdin: "stdin", windowId: nil, workspace: nil), """
                {"args":["args"],"stdin":"stdin","windowId":null,"workspace":null}
                """),
        ]
        for (req, expectedJson) in testData {
            let data = try! encoder.encode(req)
            let str = String.init(data: data, encoding: .utf8)!
            assertEquals(str, expectedJson)
        }
    }
}
