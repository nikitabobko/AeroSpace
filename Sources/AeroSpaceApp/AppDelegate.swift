import AppBundle
import AppKit
import Cocoa
import Combine
import Common
import Foundation
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    @ObservedObject var viewModel: TrayMenuModel = TrayMenuModel.shared
    private var statusBarItem: NSStatusItem?
    private var iconHostingView: NSHostingView<AnyView>?
    private var cancellables = Set<AnyCancellable>()
    private var menu: NSMenu?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        initAppBundle()
        setupStatusBarItem()
        configureMenu()
        setupObservers()
    }

    private func setupStatusBarItem() {
        // Create status bar item with fixed width for consistency
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusBarItem?.button {
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
        }

        updateStatusBarIcon()
    }
    
    private func createStatusBarIcon() -> some View {
        StatusBarIndicator(viewModel: self.viewModel)
    }

    private func updateStatusBarIcon() {
        guard let button = statusBarItem?.button else { return }

        // Remove existing icon view if present
        iconHostingView?.removeFromSuperview()

        // Create new icon view
        let iconView = NSHostingView(rootView: AnyView(createStatusBarIcon()))
        
        // Force layout to ensure proper sizing
        iconView.layout()
        
        // Use a fixed size based on the status bar height
        let size = NSSize(width: 22, height: 22)  // Standard menu bar icon size
        
        // Set the button's frame size first
        button.frame.size = size
        
        // Set icon view frame to match button exactly
        iconView.frame = NSRect(origin: .zero, size: size)
        
        button.addSubview(iconView)
        iconHostingView = iconView
        
        // Use constraints to pin the icon view to all edges of the button
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            iconView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            iconView.topAnchor.constraint(equalTo: button.topAnchor),
            iconView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        
        // Force a redraw of the button
        button.needsDisplay = true
    }

    private func setupObservers() {
        // Set up observation of viewModel changes
        viewModel.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusBarIcon()
                self?.updateMenuItems()
            }
            .store(in: &cancellables)
    }

    private func configureMenu() {
        let menu = NSMenu()
        self.menu = menu

        updateMenuItems()

        if let button = statusBarItem?.button {
            button.menu = menu
        }
    }

    private func updateMenuItems() {
        guard let menu = self.menu else { return }

        menu.removeAllItems()

        let shortIdentification = "\(aeroSpaceAppName) v\(aeroSpaceAppVersion) \(gitShortHash)"

        // Add identification item
        let identificationItem = NSMenuItem(title: shortIdentification, action: nil, keyEquivalent: "")
        menu.addItem(identificationItem)

        // Add copy to clipboard item
        let copyIdToClip = NSMenuItem(
            title: "Copy to clipboard", action: #selector(copyIdToClip(_:)), keyEquivalent: "c")
        copyIdToClip.target = self
        menu.addItem(copyIdToClip)

        menu.addItem(NSMenuItem.separator())

        // Add workspaces section if enabled
        if viewModel.isEnabled {
            let workspacesHeader = NSMenuItem(title: "Workspaces:", action: nil, keyEquivalent: "")
            menu.addItem(workspacesHeader)

            for workspace in Workspace.all {
                let monitor =
                    workspace.isVisible || !workspace.isEffectivelyEmpty ? " - \(workspace.workspaceMonitor.name)" : ""
                let workspaceItem = NSMenuItem(
                    title: workspace.name + monitor, action: #selector(workspaceSelected(_:)), keyEquivalent: "")
                workspaceItem.target = self
                workspaceItem.representedObject = workspace
                menu.addItem(workspaceItem)
            }

            menu.addItem(NSMenuItem.separator())
        }

        // Add enable/disable item
        let enableItem = NSMenuItem(
            title: viewModel.isEnabled ? "Disable" : "Enable", action: #selector(toggleEnabled(_:)), keyEquivalent: "e")
        enableItem.target = self
        menu.addItem(enableItem)

        // Add open config item
        let editor = getTextEditorToOpenConfig()
        let openConfigItem = NSMenuItem(
            title: "Open config in '\(editor.lastPathComponent)'", action: #selector(openConfig(_:)), keyEquivalent: "o"
        )
        openConfigItem.target = self
        menu.addItem(openConfigItem)

        // Add reload config item if enabled
        if viewModel.isEnabled {
            let reloadConfigItem = NSMenuItem(
                title: "Reload config", action: #selector(reloadConfigAction(_:)), keyEquivalent: "r")
            reloadConfigItem.target = self
            menu.addItem(reloadConfigItem)
        }

        // Add quit item
        let quitMenuItem = NSMenuItem(title: "Quit \(aeroSpaceAppName)", action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)

        menu.font =
            NSFont(name: config.fontFamily, size: config.fontSize)
            ?? .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
    }

    @objc private func copyIdToClip(_ sender: Any?) {
        let identification = "\(aeroSpaceAppName) v\(aeroSpaceAppVersion) \(gitHash)"
        identification.copyToClipboard()
    }

    @objc private func workspaceSelected(_ sender: NSMenuItem) {
        if let workspace = sender.representedObject as? Workspace {
            refreshSession { _ = workspace.focusWorkspace() }
        }
    }

    @objc private func toggleEnabled(_ sender: Any?) {
        refreshSession {
            let newState = !TrayMenuModel.shared.isEnabled
            TrayMenuModel.shared.isEnabled = newState

            if newState {
                // Enable logic
                for workspace in Workspace.all {
                    for window in workspace.allLeafWindowsRecursive where window.isFloating {
                        window.lastFloatingSize = window.getSize() ?? window.lastFloatingSize
                    }
                }
                activateMode(mainModeId)
            } else {
                // Disable logic
                activateMode(nil)
                for workspace in Workspace.all {
                    workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideFromCorner() }
                    workspace.layoutWorkspace()  // Unhide tiling windows from corner
                }
            }
        }
    }

    @objc private func openConfig(_ sender: Any?) {
        let editor = getTextEditorToOpenConfig()
        let fallbackConfig: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: configDotfileName)

        switch findCustomConfigUrl() {
        case .file(let url):
            url.open(with: editor)
        case .noCustomConfigExists:
            _ = try? FileManager.default.copyItem(atPath: defaultConfigUrl.path, toPath: fallbackConfig.path)
            fallbackConfig.open(with: editor)
        case .ambiguousConfigError:
            fallbackConfig.open(with: editor)
        }
    }

    @objc private func reloadConfigAction(_ sender: Any?) {
        refreshSession { _ = reloadConfig() }
    }

    @objc func statusBarButtonClicked(_ sender: Any?) {
        if let button = statusBarItem?.button {
            button.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY), in: button)
        }
    }

    @objc func quitApp() {
        terminationHandler.beforeTermination()
        terminateApp()
    }

    func getTextEditorToOpenConfig() -> URL {
        NSWorkspace.shared.urlForApplication(toOpen: findCustomConfigUrl().urlOrNil ?? defaultConfigUrl)?
            .takeIf { $0.lastPathComponent != "Xcode.app" }
            ?? URL(filePath: "/System/Applications/TextEdit.app")
    }
}
