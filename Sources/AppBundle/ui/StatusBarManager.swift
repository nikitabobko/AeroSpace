import AppKit
import Common
import SwiftUI

@MainActor
class StatusBarManager: ObservableObject {
    static let shared = StatusBarManager()
    
    private var panel: NSPanel?
    private var hostingView: NSHostingView<CenteredWorkspaceBar>?
    private var screenObserver: Any?
    
    private init() {
        setupScreenChangeObserver()
    }
    
    func setupCenteredBar(viewModel: TrayMenuModel) {
        guard viewModel.experimentalUISettings.centeredBarEnabled else {
            removeCenteredBar()
            return
        }
        
        if panel == nil {
            panel = createCenteredPanel()
        }
        
        // Build content sized to menu bar height
        let screenForContent = resolveTargetScreen() ?? NSScreen.screens.first
        let barHeight = screenForContent.map(menuBarHeight(for:)).map { max($0, 24) } ?? 28
        let contentView = CenteredWorkspaceBar(viewModel: viewModel, barHeight: barHeight)
        
        if hostingView == nil {
            hostingView = NSHostingView(rootView: contentView)
        } else {
            hostingView?.rootView = contentView
        }
        
        guard let panel = panel,
              let hostingView = hostingView else { return }
        
        // Set the hosting view as the panel's content view
        panel.contentView = hostingView

        // Apply settings and update the frame/position
        applySettingsToPanel(panel)
        updateFrameAndPosition()
        
        // Show the panel without taking key focus
        panel.orderFrontRegardless()
    }
    
    func updateCenteredBar(viewModel: TrayMenuModel) {
        guard viewModel.experimentalUISettings.centeredBarEnabled else {
            removeCenteredBar()
            return
        }
        
        if panel == nil {
            setupCenteredBar(viewModel: viewModel)
        } else {
            // Update the content (recompute bar height for current screen)
            let screenForContent = resolveTargetScreen() ?? NSScreen.screens.first
            let barHeight = screenForContent.map(menuBarHeight(for:)).map { max($0, 24) } ?? 28
            hostingView?.rootView = CenteredWorkspaceBar(viewModel: viewModel, barHeight: barHeight)
            if let panel {
                applySettingsToPanel(panel)
            }
            updateFrameAndPosition()
        }
    }
    
    private func createCenteredPanel() -> NSPanel {
        // Use custom panel subclass to bypass menu bar constraint
        let panel = CenteredBarPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // Level and behaviors are applied from settings below
        // Show on all Spaces and during fullscreen as an auxiliary overlay
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        // Visuals and interaction
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false  // Keep interactive
        // Panel behavior
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        // Apply current settings (level etc.)
        applySettingsToPanel(panel)
        return panel
    }
    
    private func updateFrameAndPosition() {
        guard let panel = panel,
              let hostingView = hostingView else { return }
        
        // Calculate the required size
        let fittingSize = hostingView.fittingSize
        
        // Resolve target screen based on settings
        let screen = resolveTargetScreen()
        guard let screen = screen else { return }
        
        // Use screen.frame for full screen including menu bar area
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame  // Keep for debug logging
        let barHeight = max(menuBarHeight(for: screen), 24)
        
        // Debug logging
        print("DEBUG: Screen frame: \(screenFrame)")
        print("DEBUG: Visible frame: \(visibleFrame)")
        print("DEBUG: Fitting size: \(fittingSize)")
        
        // Force minimum size to ensure visibility
        let width = max(fittingSize.width, 300)  // Force 300px minimum width
        let height = barHeight  // Exactly match menu bar height
        
        // Position to exactly occupy the menu bar area
        let x = screenFrame.midX - width / 2  // Center horizontally
        let y = visibleFrame.maxY             // Bottom aligns with menu bar bottom
        
        print("DEBUG: Final position: x=\(x), y=\(y), width=\(width), height=\(height)")
        
        // Set the panel frame
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)

        // Ensure SwiftUI content matches the new bar height
        hostingView.rootView = CenteredWorkspaceBar(viewModel: TrayMenuModel.shared, barHeight: barHeight)
    }
    
    func removeCenteredBar() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        hostingView = nil
    }
    
    func toggleCenteredBar(viewModel: TrayMenuModel) {
        if viewModel.experimentalUISettings.centeredBarEnabled {
            setupCenteredBar(viewModel: viewModel)
        } else {
            removeCenteredBar()
        }
    }
    
    private func setupScreenChangeObserver() {
        // Listen for screen configuration changes
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateFrameAndPosition()
            }
        }
    }
    
    func cleanup() {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
        }
        removeCenteredBar()
    }

    // MARK: - Helpers
    private func applySettingsToPanel(_ panel: NSPanel) {
        let settings = TrayMenuModel.shared.experimentalUISettings
        panel.level = switch settings.centeredBarWindowLevel {
            case .status: .statusBar
            case .popup: .popUpMenu
            case .screensaver: .screenSaver
        }
    }

    private func resolveTargetScreen() -> NSScreen? {
        let settings = TrayMenuModel.shared.experimentalUISettings
        switch settings.centeredBarTargetDisplay {
            case .primary:
                let idx = mainMonitor.monitorAppKitNsScreenScreensId - 1
                return NSScreen.screens.indices.contains(idx) ? NSScreen.screens[idx] : NSScreen.screens.first
            case .mouse:
                let mouse = NSEvent.mouseLocation
                return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.screens.first
            case .focusedWorkspaceMonitor:
                let monitor = focus.workspace.workspaceMonitor
                let idx = monitor.monitorAppKitNsScreenScreensId - 1
                return NSScreen.screens.indices.contains(idx) ? NSScreen.screens[idx] : NSScreen.screens.first
        }
    }

    private func menuBarHeight(for screen: NSScreen) -> CGFloat {
        let h = screen.frame.maxY - screen.visibleFrame.maxY
        return h > 0 ? h : 28 // fallback
    }
}
