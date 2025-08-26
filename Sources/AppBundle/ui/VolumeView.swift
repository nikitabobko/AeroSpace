import AppKit
import SwiftUI

public class VolumePanel: NSPanelHud {
    @MainActor public static var shared: VolumePanel = VolumePanel()
    private var timer: Timer?
    private var panelFrame = NSRect(x: 0, y: 0, width: 50, height: 206)

    override private init() {
        super.init()
    }

    public func update(with volume: Float) {
        timer?.invalidate()
        self.contentView?.subviews.removeAll()
        let hostingView = NSHostingView(rootView: VolumeView(volume: volume))
        hostingView.frame = NSRect(x: 0, y: 0, width: panelFrame.width, height: panelFrame.height)
        self.contentView?.addSubview(hostingView)
        panelFrame.origin.x = mainMonitor.width - panelFrame.size.width - 20
        panelFrame.origin.y = (mainMonitor.height - panelFrame.size.height) / 2
        self.setFrame(panelFrame, display: true)
        self.orderFrontRegardless()
        startTimer()
    }

    func startTimer() {
        timer = .scheduledTimer(withTimeInterval: 2 /* seconds */, repeats: false) { _ in
            Task { @MainActor [weak self] in
                self?.close()
            }
        }
    }
}

struct VolumeView: View {
    @State var volume: Float? = nil

    @Environment(\.colorScheme) var colorScheme: ColorScheme
    private var barColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    private var fontColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    private var speakerImage: String {
        guard let volume else { return "speaker.fill" }
        switch volume {
            case 0.00 ..< 0.01: return "speaker.slash.fill"
            case 0.01 ..< 0.25: return "speaker.fill"
            case 0.25 ..< 0.50: return "speaker.1.fill"
            case 0.50 ..< 0.75: return "speaker.2.fill"
            default: return "speaker.3.fill"
        }
    }
    private let bar = CGSize(width: 44, height: 200)

    var body: some View {
        ZStack(alignment: .bottom) {
            if let volume {
                Rectangle()
                    .fill(Color.gray.opacity(0.8))
                Rectangle()
                    .fill(barColor)
                    .frame(height: CGFloat(volume) * bar.height)
                VStack {
                    Text("\(Int(volume * 100))%")
                        .font(.system(size: 12, weight: .bold))
                    Image(systemName: speakerImage)
                        .frame(width: 30, height: 30, alignment: .center)
                        .padding(.bottom, 10)
                }
                .foregroundStyle(fontColor)
            }
        }
        .frame(width: bar.width, height: bar.height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    VolumeView(volume: 0.5).padding()
}
