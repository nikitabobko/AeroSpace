import AppKit
import Common

private extension FrameValue {
    func resolve(current: CGFloat) -> Int {
        switch self {
            case .set(let v): v
            case .add(let v): Int(current) + v
            case .subtract(let v): Int(current) - v
        }
    }
}

struct SetFrameCommand: Command {
    let args: SetFrameCmdArgs
    let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let window = target.windowOrNil else {
            return io.err(noWindowIsFocused)
        }
        guard window.isFloating else {
            return io.err("set-frame only works on floating windows")
        }

        guard let currentRect = try await window.getAxRect() else {
            return io.err("Can't get window frame")
        }

        let newX = CGFloat(args.rawX?.resolve(current: currentRect.topLeftX) ?? Int(currentRect.topLeftX))
        let newY = CGFloat(args.rawY?.resolve(current: currentRect.topLeftY) ?? Int(currentRect.topLeftY))
        let newWidth = CGFloat(args.rawWidth?.resolve(current: currentRect.width) ?? Int(currentRect.width))
        let newHeight = CGFloat(args.rawHeight?.resolve(current: currentRect.height) ?? Int(currentRect.height))

        if newWidth <= 0 || newHeight <= 0 {
            return io.err("Width and height must be positive")
        }

        let center = CGPoint(x: newX + newWidth / 2, y: newY + newHeight / 2)
        let insideMonitor = monitors.contains { $0.rect.contains(center) }
        if !insideMonitor {
            return io.err("Resulting frame center (\(Int(center.x)), \(Int(center.y))) is outside all monitors")
        }

        window.setAxFrame(CGPoint(x: newX, y: newY), CGSize(width: newWidth, height: newHeight))
        window.lastFloatingSize = CGSize(width: newWidth, height: newHeight)
        return true
    }
}
