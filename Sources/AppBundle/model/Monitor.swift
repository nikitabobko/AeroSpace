import AppKit
import Common

private struct MonitorImpl {
    let monitorAppKitNsScreenScreensId: Int
    let uuid: UUID?
    let serial: UInt32?
    let contextualId: CGDirectDisplayID
    let name: String
    let rect: Rect
    let visibleRect: Rect
}

extension MonitorImpl: Monitor {
    var height: CGFloat { rect.height }
    var width: CGFloat { rect.width }
}

/// Use it instead of NSScreen because it can be mocked in tests
protocol Monitor: AeroAny {
    /// The index in NSScreen.screens array. 1-based index
    var monitorAppKitNsScreenScreensId: Int { get }
    var uuid: UUID? { get }
    var serial: UInt32? { get }
    var contextualId: CGDirectDisplayID { get }
    var name: String { get }
    var rect: Rect { get }
    var visibleRect: Rect { get }
    var width: CGFloat { get }
    var height: CGFloat { get }
}

class LazyMonitor: Monitor {
    private let screen: NSScreen
    let monitorAppKitNsScreenScreensId: Int
    let uuid: UUID?
    let serial: UInt32?
    let contextualId: CGDirectDisplayID
    let name: String
    let width: CGFloat
    let height: CGFloat
    private var _rect: Rect?
    private var _visibleRect: Rect?

    init(monitorAppKitNsScreenScreensId: Int, _ screen: NSScreen) {
        self.monitorAppKitNsScreenScreensId = monitorAppKitNsScreenScreensId
        self.uuid = screen.uuid
        self.serial = screen.serial
        self.contextualId = screen.displayId
        self.name = screen.localizedName
        self.width = screen.frame.width // Don't call rect because it would cause recursion during mainMonitor init
        self.height = screen.frame.height // Don't call rect because it would cause recursion during mainMonitor init
        self.screen = screen
    }

    var rect: Rect {
        _rect ?? screen.rect.also { _rect = $0 }
    }

    var visibleRect: Rect {
        _visibleRect ?? screen.visibleRect.also { _visibleRect = $0 }
    }
}

// Note to myself: Don't use NSScreen.main, it's garbage
// 1. The name is misleading, it's supposed to be called "focusedScreen"
// 2. It's inaccurate because NSScreen.main doesn't work correctly from NSWorkspace.didActivateApplicationNotification &
//    kAXFocusedWindowChangedNotification callbacks.
private extension NSScreen {
    // From https://github.com/AerialScreensaver/AerialCompanion/blob/b2cbb355e/AerialUpdater/Model/Helpers/NSScreen%2BId.swift#L9-L15,
    // via https://gist.github.com/salexkidd/bcbea2372e92c6e5b04cbd7f48d9b204
    var displayId: CGDirectDisplayID {
        return deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
    }

    var uuid: UUID? {
        let cfUuid = CGDisplayCreateUUIDFromDisplayID(displayId).takeRetainedValue()
        return UUID(uuidString: CFUUIDCreateString(nil, cfUuid) as String)
    }

    var serial: UInt32? {
        switch CGDisplaySerialNumber(displayId) {
            case 0x0000_0000,
                0xFFFF_FFFF:
                return nil
            case let serial:
                return serial
        }
    }

    func toMonitor(monitorAppKitNsScreenScreensId: Int) -> Monitor {
        MonitorImpl(
            monitorAppKitNsScreenScreensId: monitorAppKitNsScreenScreensId,
            uuid: uuid,
            serial: serial,
            contextualId: displayId,
            name: localizedName,
            rect: rect,
            visibleRect: visibleRect
        )
    }

    var isMainScreen: Bool {
        frame.minX == 0 && frame.minY == 0
    }

    /// The property is a replacement for Apple's crazy ``frame``
    ///
    /// - For ``MacWindow.topLeftCorner``, (0, 0) is main screen top left corner, and positive y-axis goes down.
    /// - For ``frame``, (0, 0) is main screen bottom left corner, and positive y-axis goes up (which is crazy).
    ///
    /// The property "normalizes" ``frame``
    var rect: Rect { frame.monitorFrameNormalized() }

    /// Same as ``rect`` but for ``visibleFrame``
    var visibleRect: Rect { visibleFrame.monitorFrameNormalized() }
}

private let testMonitorRect = Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080)
private let testMonitor = MonitorImpl(
    monitorAppKitNsScreenScreensId: 1,
    uuid: UUID(uuidString: "3bafffce-f88e-48ab-98ee-5a0295879f29"),
    serial: nil,
    contextualId: 12345,
    name: "Test Monitor",
    rect: testMonitorRect,
    visibleRect: testMonitorRect
)

var mainMonitor: Monitor {
    if isUnitTest { return testMonitor }
    let elem = NSScreen.screens.withIndex.singleOrNil(where: \.value.isMainScreen)!
    return LazyMonitor(monitorAppKitNsScreenScreensId: elem.index + 1, elem.value)
}

var monitors: [Monitor] {
    isUnitTest
        ? [testMonitor]
        : NSScreen.screens.enumerated().map { $0.element.toMonitor(monitorAppKitNsScreenScreensId: $0.offset + 1) }
}

var sortedMonitors: [Monitor] {
    monitors.sortedBy([\.rect.minX, \.rect.minY])
}
