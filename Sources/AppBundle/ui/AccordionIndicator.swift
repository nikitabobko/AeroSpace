import AppKit
import Common
import SwiftUI

/// Manages overlay panels that show app icons for windows in accordion containers
@MainActor
final class AccordionIndicatorManager {
    static let shared = AccordionIndicatorManager()

    /// Pool of reusable panels keyed by a stable identifier
    private var panels: [ObjectIdentifier: AccordionIndicatorPanel] = [:]

    private init() {}

    func refresh() {
        guard config.accordionIndicator.enabled else {
            hideAll()
            return
        }

        var activeContainerIds: Set<ObjectIdentifier> = []

        for workspace in Workspace.all where workspace.isVisible {
            collectAccordionContainers(workspace.rootTilingContainer, into: &activeContainerIds)
        }

        // Remove panels for containers that no longer exist or aren't visible
        for (id, panel) in panels where !activeContainerIds.contains(id) {
            panel.close()
            panels.removeValue(forKey: id)
        }
    }

    private func collectAccordionContainers(_ node: TreeNode, into ids: inout Set<ObjectIdentifier>) {
        if let container = node as? TilingContainer {
            if container.layout == .accordion && container.children.count > 1 {
                let id = ObjectIdentifier(container)
                ids.insert(id)
                updatePanel(for: container, id: id)
            }
            for child in container.children {
                collectAccordionContainers(child, into: &ids)
            }
        }
    }

    private func updatePanel(for container: TilingContainer, id: ObjectIdentifier) {
        guard let rect = container.lastAppliedLayoutPhysicalRect else { return }

        let windows = container.children.compactMap { $0 as? Window }
        guard !windows.isEmpty else { return }

        let mruWindow = container.mostRecentChild as? Window

        let entries: [AccordionIndicatorEntry] = windows.map { window in
            let icon: NSImage = if let macWindow = window as? MacWindow {
                macWindow.macApp.nsApp.icon ?? NSImage(named: NSImage.applicationIconName)!
            } else {
                NSImage(named: NSImage.applicationIconName)!
            }
            return AccordionIndicatorEntry(
                windowId: window.windowId,
                icon: icon,
                isFocused: window === mruWindow,
            )
        }

        let panel: AccordionIndicatorPanel
        if let existing = panels[id] {
            panel = existing
        } else {
            panel = AccordionIndicatorPanel()
            panels[id] = panel
        }

        let indicatorConfig = config.accordionIndicator
        let position = indicatorConfig.position
        let iconSize = CGFloat(indicatorConfig.iconSize)
        let iconPadding = CGFloat(indicatorConfig.iconPadding)
        let panelPadding = CGFloat(indicatorConfig.barPadding)

        let totalIcons = CGFloat(entries.count)
        let isVerticalBar: Bool // The indicator bar orientation (icons stacked vertically or horizontally)

        let panelWidth: CGFloat
        let panelHeight: CGFloat
        let panelX: CGFloat
        let panelY: CGFloat

        let margin: CGFloat = 4 // gap between indicator and window edge

        switch position {
            case .left, .right:
                isVerticalBar = true
                panelWidth = iconSize + panelPadding * 2
                panelHeight = totalIcons * (iconSize + iconPadding) - iconPadding + panelPadding * 2
                panelY = screenFlipY(rect.topLeftY, height: panelHeight)
                panelX = position == .left
                    ? rect.topLeftX - panelWidth - margin
                    : rect.topLeftX + rect.width + margin
            case .top, .bottom:
                isVerticalBar = false
                panelWidth = totalIcons * (iconSize + iconPadding) - iconPadding + panelPadding * 2
                panelHeight = iconSize + panelPadding * 2
                panelX = rect.topLeftX
                panelY = position == .top
                    ? screenFlipY(rect.topLeftY - panelHeight - margin, height: panelHeight)
                    : screenFlipY(rect.topLeftY + rect.height + margin, height: panelHeight)
        }

        let model = AccordionIndicatorModel(
            entries: entries,
            isVertical: isVerticalBar,
            iconSize: iconSize,
            iconPadding: iconPadding,
            barPadding: panelPadding,
            onIconClick: { windowId in
                Task { @MainActor in
                    if let window = Window.get(byId: windowId) {
                        _ = window.focusWindow()
                        window.nativeFocus()
                        scheduleRefreshSession(.menuBarButton)
                    }
                }
            },
        )
        let hostingView = NSHostingView(rootView: AccordionIndicatorView(model: model))
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)

        panel.contentView?.subviews.removeAll()
        panel.contentView?.addSubview(hostingView)
        panel.setFrame(NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight), display: true)
        panel.orderFrontRegardless()
    }

    func hideAll() {
        for (_, panel) in panels {
            panel.close()
        }
        panels.removeAll()
    }

    /// Convert AeroSpace top-left Y coordinate to macOS bottom-left Y coordinate
    private func screenFlipY(_ topLeftY: CGFloat, height: CGFloat) -> CGFloat {
        guard let screen = NSScreen.main else { return topLeftY }
        return screen.frame.height - topLeftY - height
    }
}

// MARK: - Panel

final class AccordionIndicatorPanel: NSPanelHud {
    override init() {
        super.init()
        self.hasShadow = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.canHide = false
        self.styleMask.insert(.nonactivatingPanel)
        // Prevent the panel from ever becoming key or main
        self.becomesKeyOnlyIfNeeded = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Data Model

struct AccordionIndicatorEntry: Identifiable {
    let windowId: UInt32
    let icon: NSImage
    let isFocused: Bool
    var id: UInt32 { windowId }
}

struct AccordionIndicatorModel {
    let entries: [AccordionIndicatorEntry]
    let isVertical: Bool
    let iconSize: CGFloat
    let iconPadding: CGFloat
    let barPadding: CGFloat
    let onIconClick: (UInt32) -> Void
}

// MARK: - SwiftUI View

struct AccordionIndicatorView: View {
    let model: AccordionIndicatorModel

    var body: some View {
        Group {
            if model.isVertical {
                VStack(spacing: model.iconPadding) {
                    iconViews
                }
            } else {
                HStack(spacing: model.iconPadding) {
                    iconViews
                }
            }
        }
        .padding(model.barPadding)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var iconViews: some View {
        ForEach(model.entries) { entry in
            Image(nsImage: entry.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: model.iconSize, height: model.iconSize)
                .opacity(entry.isFocused ? 1.0 : 0.4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(entry.isFocused ? Color.accentColor : Color.clear, lineWidth: 2),
                )
                .onTapGesture {
                    model.onIconClick(entry.windowId)
                }
        }
    }
}

// MARK: - Config

struct AccordionIndicatorConfig: ConvenienceCopyable, Equatable {
    var enabled: Bool = false
    var iconSize: Int = 30
    var iconPadding: Int = 2
    var barPadding: Int = 4
    var position: AccordionIndicatorPosition = .left
    var accordionVerticalNavigation: Bool = false
}

enum AccordionIndicatorPosition: String, Equatable {
    case left, right, top, bottom
}

// MARK: - Config Parsing

private let accordionIndicatorParser: [String: any ParserProtocol<AccordionIndicatorConfig>] = [
    "enabled": Parser(\.enabled, parseBool),
    "icon-size": Parser(\.iconSize, parseInt),
    "icon-padding": Parser(\.iconPadding, parseInt),
    "bar-padding": Parser(\.barPadding, parseInt),
    "position": Parser(\.position, parseAccordionIndicatorPosition),
    "vertical-navigation": Parser(\.accordionVerticalNavigation, parseBool),
]

func parseAccordionIndicator(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> AccordionIndicatorConfig {
    parseTable(raw, AccordionIndicatorConfig(), accordionIndicatorParser, backtrace, &errors)
}

private func parseAccordionIndicatorPosition(_ raw: Json, _ backtrace: ConfigBacktrace) -> ParsedConfig<AccordionIndicatorPosition> {
    parseString(raw, backtrace).flatMap {
        AccordionIndicatorPosition(rawValue: $0)
            .orFailure(.semantic(backtrace, "Can't parse accordion indicator position '\($0)'. Expected: left, right, top, bottom"))
    }
}
