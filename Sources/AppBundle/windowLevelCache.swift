import Common
import CoreGraphics
import Foundation

@MainActor private var cache: [UInt32: MacOsWindowLevel] = [:]
@MainActor private var wip: AwaitableOneTimeBroadcastLatch? = nil

@MainActor func getWindowLevel(forNativeId windowId: UInt32, _ cm: CancellationMode) async throws -> MacOsWindowLevel? {
    if let existing = cache[windowId] { return existing }
    if let wip {
        try await wip.await(cm)
        return cache[windowId]
    }
    wip = AwaitableOneTimeBroadcastLatch()
    cache = await computeCache()
    wip = nil
    await wip?.signalToAll()
    return cache[windowId]
}

@concurrent private func computeCache() async -> [UInt32: MacOsWindowLevel] {
    var result: [UInt32: MacOsWindowLevel] = [:]
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionAll)
    guard let cfArray = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [CFDictionary] else { return [:] }
    for elem in cfArray {
        let dict = elem as NSDictionary

        guard let _windowLayer = dict[kCGWindowLayer] else { continue }
        let windowLayer = ((_windowLayer as! CFNumber) as NSNumber).intValue

        guard let _windowId = dict[kCGWindowNumber] else { continue }
        let windowId = ((_windowId as! CFNumber) as NSNumber).uint32Value

        result[windowId] = .new(windowLevel: windowLayer)
    }
    return result
}

enum MacOsWindowLevel: Sendable, Equatable {
    case normalWindow
    case alwaysOnTopWindow
    case unknown(windowLevel: Int)

    static func new(windowLevel: Int) -> MacOsWindowLevel {
        switch windowLevel {
            case 0: .normalWindow
            case 3: .alwaysOnTopWindow
            default: .unknown(windowLevel: windowLevel)
        }
    }

    static func fromJson(_ json: Json) -> MacOsWindowLevel? {
        switch json {
            case .string("normalWindow"): .normalWindow
            case .string("alwaysOnTopWindow"): .alwaysOnTopWindow
            case .int(let int): .new(windowLevel: Int(exactly: int).orDie())
            default: nil
        }
    }

    func toJson() -> Json {
        switch self {
            case .normalWindow: .string("normalWindow")
            case .alwaysOnTopWindow: .string("alwaysOnTopWindow")
            case .unknown(let layerNumber): .int(layerNumber)
        }
    }
}
