import CoreGraphics
import Foundation

@MainActor
private var cache: [UInt32: MacOsWindowLevel] = [:]

@MainActor
func getWindowLevel(for windowId: UInt32) -> MacOsWindowLevel? {
    if let existing = cache[windowId] { return existing }

    var result: [UInt32: MacOsWindowLevel] = [:]
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    guard let cfArray = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [CFDictionary] else { return nil }
    for elem in cfArray {
        let dict = elem as NSDictionary

        guard let _windowLayer = dict[kCGWindowLayer] else { continue }
        let windowLayer = ((_windowLayer as! CFNumber) as NSNumber).intValue

        guard let _windowId = dict[kCGWindowNumber] else { continue }
        let windowId = ((_windowId as! CFNumber) as NSNumber).uint32Value

        result[windowId] = .new(layerNumber: windowLayer)
    }
    cache = result
    return result[windowId]
}

enum MacOsWindowLevel: Sendable, Codable, Equatable {
    case normalWindow
    case alwaysOnTopWindow
    case unknown(layerNumber: Int)

    static func new(layerNumber: Int) -> MacOsWindowLevel {
        switch layerNumber {
            case 0: .normalWindow
            case 3: .alwaysOnTopWindow
            default: .unknown(layerNumber: layerNumber)
        }
    }

    var normalize: MacOsWindowLevel {
        switch self {
            case .unknown(let layerNumber): .new(layerNumber: layerNumber)
            default: self
        }
    }
}
