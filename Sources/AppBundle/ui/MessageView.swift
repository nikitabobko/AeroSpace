import Common
import SwiftUI

@MainActor
public func getMessageWindow(messageModel: MessageModel) -> some Scene {
    // Using SwiftUI.Window because another class in AeroSpace is already called Window
    SwiftUI.Window(messageModel.message?.title ?? aeroSpaceAppName, id: messageWindowId) {
        MessageView(model: messageModel)
            .onAppear {
                // Set activation policy; otherwise, AeroSpace windows won't be able to receive focus and accept keyborad input
                NSApp.setActivationPolicy(.accessory)
                NSApplication.shared.windows.forEach {
                    if $0.identifier?.rawValue == messageWindowId {
                        $0.level = .floating
                    }
                }
            }
    }
    .windowResizability(.contentMinSize)
    //.windowLevel(.floating) //This might be the SwiftUI way of doing window level instead of the onAppear block above, but it's only available from macOS 15.0
}

public let messageWindowId = "\(aeroSpaceAppName).messageView"

public struct MessageView: View {
    @StateObject private var model: MessageModel
    @Environment(\.dismiss) private var dismiss
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
                        TextEditor(text: .constant(model.message?.body ?? ""))
                            .font(.system(size: 12).monospaced())
                            .focused($focus)
                            .onExitCommand {
                                // Escape to remove focus from the TextEditor, and then you can hit Return to trigger the Close,
                                // or use 'CMD + ,' for open config and 'CMD + R' for reload config (same as the menu shortcuts)
                                focus = false
                            }
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
                            reloadConfigButton
                            openConfigButton
                    }
                }
                Button("Close") {
                    model.message = nil
                }
                .keyboardShortcut(.defaultAction)
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

public class MessageModel: ObservableObject {
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

#Preview {
    MessageView(model: MessageModel.shared)
        .onAppear {
            MessageModel.shared.message = Message(type: .config, description: "Description", body: "Body")
        }
}
