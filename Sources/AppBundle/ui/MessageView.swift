import Common
import SwiftUI

@MainActor
public func getMessageWindow(messageModel: MessageModel) -> some Scene {
    // Using SwiftUI.Window because another class in AeroSpace is already called Window
    SwiftUI.Window(messageModel.message?.title ?? aeroSpaceAppName, id: messageWindowId) {
        MessageView(model: messageModel)
            .onAppear {
                // Set activation policy; otherwise, AeroSpace windows won't be able to receive focus and accept keyboard input
                NSApp.setActivationPolicy(.accessory)
                NSApplication.shared.windows.forEach {
                    if $0.identifier?.rawValue == messageWindowId {
                        $0.level = .floating
                        $0.styleMask.remove(.miniaturizable) // Disable minimize button, because we don't unminimize the window on config error
                    }
                }
            }
        // .windowMinimizeBehavior(WindowInteractionBehavior.disabled) // SwiftUI way of hiding minimize button. Available only since macOS 15
    }
    .windowResizability(.contentMinSize)
    //.windowLevel(.floating) //This might be the SwiftUI way of doing window level instead of the onAppear block above, but it's only available from macOS 15.0
}

public let messageWindowId = "\(aeroSpaceAppName).messageView"

public struct MessageView: View {
    @StateObject private var model: MessageModel
    @Environment(\.dismiss) private var dismiss: DismissAction
    @FocusState var focus: Bool

    public init(model: MessageModel) {
        self._model = .init(wrappedValue: model)
    }

    public var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 48))
                Text("\(model.message?.description ?? "")")
                    .padding(.horizontal)
                    .focusable()
            }
            .padding()
            ScrollView {
                VStack(alignment: .leading) {
                    HStack {
                        let cancelOnEnterBinding: Binding<String> = Binding(
                            get: { model.message?.body ?? "" },
                            set: { newText in
                                if let prev = model.message?.body.count(where: \.isNewline), newText.count(where: \.isNewline) > prev {
                                    model.message = nil
                                }
                            },
                        )
                        TextEditor(text: cancelOnEnterBinding)
                            .font(.system(size: 12).monospaced())
                            .focused($focus)
                        //  .onKeyPress(.return) { return .handled } // enter handling alternative. Only available since macOS 14
                        Spacer()
                    }
                    Spacer()
                }
                .padding()
            }
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal)
            HStack {
                Spacer()
                if let type = model.message?.type {
                    switch type {
                        case .config:
                            reloadConfigButton(showShortcutGroup: true)
                            openConfigButton(showShortcutGroup: true)
                    }
                }
                let closeButton = Button("Close") { model.message = nil }.keyboardShortcut(.defaultAction)
                shortcutGroup(label: Image(systemName: "return.left"), content: closeButton)
            }
            .padding()
        }
        .textSelection(.enabled)
        .frame(minWidth: 480, maxWidth: 960, minHeight: 200)
        .onChange(of: model.message) { message in
            if message == nil {
                self.dismiss()
            }
        }
        .onDisappear {
            // If user closes the screen with the macOS native close (x) button and then the error is still the same, this window will not appear again
            model.message = nil
        }
        .onAppear {
            focus = true
        }
    }
}

public final class MessageModel: ObservableObject {
    @MainActor public static let shared = MessageModel()
    @Published public var message: Message? = nil

    private init() {}
}

public enum MessageType {
    case config
}

public struct Message: Hashable, Equatable {
    public let type: MessageType
    public let title: String
    public let description: String
    public let body: String

    init(type: MessageType = .config, title: String = aeroSpaceAppName, description: String, body: String) {
        self.type = type
        self.title = title
        self.description = description
        self.body = body
    }
}
