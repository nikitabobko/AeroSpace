import AppKit
import Common
import ISSoundAdditions

struct VolumeCommand: Command {
    let args: VolumeCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
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
        return true
    }
}
