import AppKit

public class NSPanelHud: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless, .hudWindow, .utilityWindow],
            backing: .buffered,
            defer: false,
        )
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = false
        self.alphaValue = 1
        self.hasShadow = true
        self.backgroundColor = .clear
    }
}
