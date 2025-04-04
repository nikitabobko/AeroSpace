import AppKit
import Common

func dumpAx(_ ax: AXUIElement, _ prefix: String, _ kind: AxKind) -> String {
    var result: [String] = []
    var ignored: [String] = []
    for key: String in ax.attrs.sortedBy({ priorityAx.contains($0) ? 0 : 1 }) {
        var raw: AnyObject?
        AXUIElementCopyAttributeValue(ax, key as CFString, &raw)
        if globalIgnore.contains(key) || kindSpecificIgnore[kind]?.contains(key) == true {
            ignored.append(key)
        } else {
            result.append("\(key): \(prettyValue(raw as Any?))".prependLines("\(prefix) "))
        }
    }
    if !ignored.isEmpty {
        result.append("\(prefix) Ignored: \(ignored.joined(separator: ", "))")
    }
    return result.joined(separator: "\n")
}

enum AxKind: Hashable {
    case button
    case window
    case app
}

private func prettyValue(_ value: Any?) -> String {
    if value is NSArray, let arr = value as? [Any?] {
        return "[\n" + arr.map(prettyValue).joined(separator: ",\n").prependLines("    ") + "\n]"
    }
    if let value {
        let ax = value as! AXUIElement
        if ax.get(Ax.roleAttr) == kAXButtonRole {
            let dumped = dumpAx(ax, "", .button).prependLines("    ")
            return "AXUIElement {\n" + dumped + "\n}"
        }
        if let windowId = ax.containingWindowId() {
            let title = ax.get(Ax.titleAttr)?.doubleQuoted ?? "nil"
            let role = ax.get(Ax.roleAttr)?.doubleQuoted ?? "nil"
            let subrole = ax.get(Ax.subroleAttr)?.doubleQuoted ?? "nil"
            return "AXUIElement(windowId=\(windowId), title=\(title), role=\(role), subrole=\(subrole))"
        }
    }
    let str = String(describing: value)
    return str.contains("\n")
        ? "\n" + str.prependLines("    ")
        : str
}

private extension AXUIElement {
    var attrs: [String] {
        var rawArray: CFArray?
        AXUIElementCopyAttributeNames(self, &rawArray)
        return rawArray as? [String] ?? []
    }
}

private let globalIgnore: Set<String> = [
    "AXChildren", // too verbose
    "AXChildrenInNavigationOrder", // too verbose
    kAXHelpAttribute, // localized - not helpful
    kAXRoleDescriptionAttribute, // localized - not helpful
]

private let kindSpecificIgnore: [AxKind: Set<String>] = [
    .button: [
        "AXFrame",
        kAXEditedAttribute,
        kAXFocusedAttribute,
        kAXPositionAttribute,
        kAXSizeAttribute,
    ],
    .app: [
        "AXEnhancedUserInterface",
        "AXPreferredLanguage",
        kAXHiddenAttribute,
    ],
]

private let priorityAx: Set<String> = [
    Ax.titleAttr.key,
    Ax.roleAttr.key,
    Ax.subroleAttr.key,
    Ax.identifierAttr.key,
]
