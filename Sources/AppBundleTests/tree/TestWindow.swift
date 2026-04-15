@testable import AppBundle
import AppKit

final class TestWindow: Window, CustomStringConvertible {
    private var _rect: Rect?
    private var customTitle: String?
    private(set) var setAxFrameCalls = 0

    @MainActor
    private init(_ id: UInt32, _ app: any AbstractApp, _ parent: NonLeafTreeNodeObject, _ adaptiveWeight: CGFloat, _ rect: Rect?, _ customTitle: String?) {
        _rect = rect
        self.customTitle = customTitle
        super.init(id: id, app, lastFloatingSize: nil, parent: parent, adaptiveWeight: adaptiveWeight, index: INDEX_BIND_LAST)
    }

    @discardableResult
    @MainActor
    static func new(
        id: UInt32,
        parent: NonLeafTreeNodeObject,
        adaptiveWeight: CGFloat = 1,
        rect: Rect? = nil,
        title: String? = nil,
        app: any AbstractApp = TestApp.shared,
    ) -> TestWindow {
        let wi = TestWindow(id, app, parent, adaptiveWeight, rect, title)
        TestApp.shared._windows.append(wi)
        return wi
    }

    nonisolated var description: String { "TestWindow(\(windowId))" }

    @MainActor
    override func nativeFocus() {
        appForTests = TestApp.shared
        TestApp.shared.focusedWindow = self
    }

    override func closeAxWindow() {
        TabHeaderTitleCache.shared.invalidate(windowId: windowId)
        unbindFromParent()
    }

    override var title: String {
        get async { // redundant async. todo create bug report to Swift
            customTitle ?? description
        }
    }

    func setTitleForTests(_ newTitle: String?) {
        customTitle = newTitle
    }

    @MainActor override func getAxRect() async throws -> Rect? { // todo change to not Optional
        _rect
    }

    override func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?) {
        guard let topLeft, let size else { return }
        setAxFrameCalls += 1
        _rect = Rect(topLeftX: topLeft.x, topLeftY: topLeft.y, width: size.width, height: size.height)
    }
}
