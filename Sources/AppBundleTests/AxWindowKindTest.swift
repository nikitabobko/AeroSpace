@testable import AppBundle
import Common
import XCTest

final class AxWindowKindTest: XCTestCase {
    func test() throws {
        for file in try FileManager.default.contentsOfDirectory(at: projectRoot.appending(path: "./axDumps"), includingPropertiesForKeys: nil) {
            let rawJson = try JSONSerialization.jsonObject(with: Data.init(contentsOf: file), options: [.json5Allowed]) as! [String: Any]
            let json = Json.newOrDie(rawJson).asDictOrDie
            let app = json["Aero.AXApp"]!.asDictOrDie
            let appBundleId = rawJson["Aero.App.appBundleId"] as? String
            assertEquals(
                json.isWindowHeuristic(axApp: app, appBundleId: appBundleId),
                rawJson["Aero.isWindowHeuristic"] as? Bool ?? dieT(),
                additionalMsg: "isWindowHeuristic doesn't match for \(file)",
            )
            assertEquals(
                json.isDialogHeuristic(appBundleId: appBundleId),
                rawJson["Aero.isDialogHeuristic"] as? Bool ?? dieT(),
                additionalMsg: "isDialogHeuristic doesn't match for \(file)",
            )
        }
    }
}

extension [String: Json]: AxUiElementMock {
    public func get<Attr>(_ attr: Attr) -> Attr.T? where Attr: ReadableAttr {
        self[attr.key]?.rawValue.flatMap { attr.getter($0 as AnyObject) }
    }

    public func containingWindowId() -> CGWindowID? {
        let windowId = self["Aero.axWindowId"]?.rawValue ?? dieT()
        if let windowId = windowId as? Int {
            return UInt32.init(windowId)
        } else {
            return windowId as? UInt32 ?? dieT()
        }
    }
}
