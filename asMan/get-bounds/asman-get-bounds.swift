// asman-get-bounds.swift
// Reads pixel bounds for all on-screen layer-0 windows using CGWindowListCopyWindowInfo.
// Does NOT require Accessibility permission.
// Outputs a JSON object keyed by CGWindowNumber (== AeroSpace window-id):
//   { "<window-id>": { "x": N, "y": N, "width": N, "height": N }, ... }
//
// Build:
//   swiftc asman-get-bounds.swift -o asman-get-bounds \
//     -framework Cocoa -framework Foundation

import Cocoa
import Foundation

let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    fputs("error: CGWindowListCopyWindowInfo returned nil\n", stderr)
    exit(1)
}

// CGWindowBounds values arrive as either Int or Double depending on the display;
// this helper normalises them to Int.
func intVal(_ dict: [String: Any], _ key: String) -> Int {
    if let v = dict[key] as? Int    { return v }
    if let v = dict[key] as? Double { return Int(v) }
    return 0
}

var result: [String: [String: Int]] = [:]
for window in list {
    guard
        let wid = window[kCGWindowNumber as String] as? Int,
        let layer = window[kCGWindowLayer as String] as? Int,
        layer == 0,
        let bounds = window[kCGWindowBounds as String] as? [String: Any]
    else { continue }

    var entry: [String: Int] = [:]
    entry["x"]      = intVal(bounds, "X")
    entry["y"]      = intVal(bounds, "Y")
    entry["width"]  = intVal(bounds, "Width")
    entry["height"] = intVal(bounds, "Height")
    result[String(wid)] = entry
}

guard let json = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]) else {
    fputs("error: JSON serialization failed\n", stderr)
    exit(1)
}
print(String(data: json, encoding: .utf8)!)
