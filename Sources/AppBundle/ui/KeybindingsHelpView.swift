import Common
import SwiftUI

@MainActor
func showKeybindingsHelp() {
    let window = KeybindingsWindowController.shared
    window.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
    window.window?.makeKeyAndOrderFront(nil)
}

private class KeybindingsWindowController: NSWindowController {
    @MainActor static let shared: KeybindingsWindowController = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Airlock Keybindings"
        window.center()
        window.isReleasedWhenClosed = false
        let controller = KeybindingsWindowController(window: window)
        controller.updateContent()
        return controller
    }()

    @MainActor func updateContent() {
        window?.contentView = NSHostingView(rootView: KeybindingsHelpContent())
    }
}

private struct KeybindingsHelpContent: View {
    @State private var bindings: [(key: String, action: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Keybindings")
                .font(.title2.bold())
                .padding(.bottom, 8)

            if bindings.isEmpty {
                Text("No keybindings configured.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(bindings.enumerated()), id: \.offset) { index, binding in
                            HStack {
                                Text(formatKey(binding.key))
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                    .frame(width: 180, alignment: .trailing)
                                Text(binding.action)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(index % 2 == 0 ? Color.clear : Color.gray.opacity(0.1))
                        }
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 450, minHeight: 300)
        .onAppear { loadBindings() }
    }

    @MainActor private func loadBindings() {
        var result: [(key: String, action: String)] = []
        for (modeName, mode) in config.modes.sorted(by: { $0.key < $1.key }) {
            let prefix = modeName == mainModeId ? "" : "[\(modeName)] "
            for (_, binding) in mode.bindings.sorted(by: { $0.value.descriptionWithKeyNotation < $1.value.descriptionWithKeyNotation }) {
                let action = binding.commands.map { $0.args.description }.joined(separator: ", ")
                result.append((key: prefix + binding.descriptionWithKeyNotation, action: action))
            }
        }
        bindings = result
    }

    private func formatKey(_ raw: String) -> String {
        raw.replacingOccurrences(of: "alt", with: "\u{2325}")
            .replacingOccurrences(of: "shift", with: "\u{21E7}")
            .replacingOccurrences(of: "cmd", with: "\u{2318}")
            .replacingOccurrences(of: "ctrl", with: "\u{2303}")
    }
}
