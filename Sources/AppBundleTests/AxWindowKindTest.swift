@testable import AppBundle
import Common
import XCTest

final class AxWindowKindTest: XCTestCase {
    func test() throws {
        try checkAxDumpsRecursive(projectRoot.appending(path: "./axDumps"))
    }
}

func checkAxDumpsRecursive(_ dir: URL) throws {
    for file in try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
        if file.isDirectory {
            try checkAxDumpsRecursive(file)
            continue
        }
        if file.pathExtension == "md" { continue }

        let rawJson = try JSONSerialization.jsonObject(with: Data.init(contentsOf: file), options: [.json5Allowed]) as! [String: Any]
        let json = Json.newOrDie(rawJson).asDictOrDie
        let app = json["Aero.AXApp"]!.asDictOrDie
        let appBundleId = (rawJson["Aero.App.appBundleId"] as? String).flatMap { KnownBundleId.init(rawValue: $0) }
        let activationPolicy: NSApplication.ActivationPolicy = .from(string: rawJson["Aero.App.nsApp.activationPolicy"] as! String)
        assertEquals(
            json.getWindowType(axApp: app, appBundleId, activationPolicy),
            AxUiElementWindowType(rawValue: rawJson["Aero.AxUiElementWindowType"] as? String ?? dieT()),
            additionalMsg: "\(file.path()):0:0: AxUiElementWindowType doesn't match",
        )
        assertEquals(
            json.isDialogHeuristic(appBundleId),
            rawJson["Aero.AxUiElementWindowType_isDialogHeuristic"] as? Bool ?? dieT(),
            additionalMsg: "\(file.path()):0:0: AxUiElementWindowType_isDialogHeuristic doesn't match",
        )
    }
}

extension [String: Json]: AxUiElementMock {
    public func get<Attr>(_ attr: Attr) -> Attr.T? where Attr: ReadableAttr {
        guard let value = self[attr.key] else {
            return isSynthetic ? dieT("\(self) doesn't contain \(attr.key)") : nil
        }
        if let value = value.rawValue {
            return attr.getter(value as AnyObject)
                ?? dieT("Value \(value) (of type \(Swift.type(of: value))) isn't convertible to \(attr.key)")
        } else {
            return nil
        }
    }

    private var isSynthetic: Bool { self[kAXAeroSynthetic] != nil }

    public func containingWindowId() -> CGWindowID? { _containingWindowId() }

    private func _containingWindowId() -> CGWindowID {
        let windowId = self["Aero.axWindowId"]?.rawValue ?? dieT()
        if let windowId = windowId as? Int {
            return UInt32.init(windowId)
        } else {
            return windowId as? UInt32 ?? dieT()
        }
    }
}

extension NSApplication.ActivationPolicy {
    static func from(string: String) -> NSApplication.ActivationPolicy {
        switch string {
            case "regular": .regular
            case "accessory": .accessory
            case "prohibited": .prohibited
            default: dieT("Unknown ActivationPolicy \(string)")
        }
    }
}

extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}
