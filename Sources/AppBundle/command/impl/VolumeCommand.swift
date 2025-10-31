import AppKit
import Common
import ISSoundAdditions

struct VolumeCommand: Command {
    let args: VolumeCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        switch args.action.val {
            case .up:
                Sound.output.increaseVolume(by: 0.0625, autoMuteUnmute: true)
            case .down:
                Sound.output.decreaseVolume(by: 0.0625, autoMuteUnmute: true)
            case .muteToggle:
                Sound.output.isMuted.toggle()
            case .muteOn:
                Sound.output.isMuted = true
            case .muteOff:
                Sound.output.isMuted = false
            case .set(let int):
                Sound.output.setVolume(Float(int) / 100, autoMuteUnmute: true)
        }
        if let volume = try? Sound.output.readVolume() {
            VolumePanel.shared.update(with: Sound.output.isMuted ? 0 : volume)
        }
        return true
    }
}
