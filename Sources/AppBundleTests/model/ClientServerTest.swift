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

    func testServerEventEncoding() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let testData: [(ServerEvent, String)] = [
            (.focusChanged(windowId: 123, workspace: "1", monitorId: 1),
             #"{"event":"focus-changed","monitorId":1,"windowId":123,"workspace":"1"}"#),
            (.focusedMonitorChanged(workspace: "2", monitorId: 1),
             #"{"event":"focused-monitor-changed","monitorId":1,"workspace":"2"}"#),
            (.workspaceChanged(workspace: "2", prevWorkspace: "1"),
             #"{"event":"focused-workspace-changed","prevWorkspace":"1","workspace":"2"}"#),
            (.modeChanged(mode: "resize"),
             #"{"event":"mode-changed","mode":"resize"}"#),
            (.windowDetected(windowId: 456, workspace: "1", appBundleId: "com.example", appName: "Example", windowTitle: "Title"),
             #"{"appBundleId":"com.example","appName":"Example","event":"window-detected","windowId":456,"windowTitle":"Title","workspace":"1"}"#),
            (.bindingTriggered(mode: "main", binding: "alt-h"),
             #"{"binding":"alt-h","event":"binding-triggered","mode":"main"}"#),
        ]
        for (event, expectedJson) in testData {
            let data = try! encoder.encode(event)
            let str = String(data: data, encoding: .utf8)!
            assertEquals(str, expectedJson)
        }
    }

    func testServerEventDecoding() {
        let testData: [(String, ServerEventType)] = [
            (#"{"event":"focus-changed","windowId":123,"workspace":"1","monitorId":1}"#, .focusChanged),
            (#"{"event":"focused-monitor-changed","workspace":"2","monitorId":1}"#, .focusedMonitorChanged),
            (#"{"event":"focused-workspace-changed","workspace":"2","prevWorkspace":"1"}"#, .workspaceChanged),
            (#"{"event":"mode-changed","mode":"resize"}"#, .modeChanged),
            (#"{"event":"window-detected","windowId":456}"#, .windowDetected),
            (#"{"event":"binding-triggered","mode":"main","binding":"alt-h"}"#, .bindingTriggered),
        ]
        for (json, expectedEventType) in testData {
            let data = json.data(using: .utf8)!
            let event = try! JSONDecoder().decode(ServerEvent.self, from: data)
            assertEquals(event.event, expectedEventType)
        }
    }
}
