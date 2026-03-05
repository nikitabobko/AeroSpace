import AppKit
import Common

let accordionPaddingOffsetKey = TreeNodeUserDataKey<CGFloat>(key: "accordionPaddingOffset")

struct AdjustAccordionPaddingCommand: Command {
    let args: AdjustAccordionPaddingCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }

        guard let window = target.windowOrNil else {
            return io.err("adjust-accordion-padding requires a focused window")
        }

        guard let container = window.parentsWithSelf
            .compactMap({ $0 as? TilingContainer })
            .first(where: { $0.layout == .accordion })
        else {
            return io.err("No accordion container found for the focused window")
        }

        let currentOffset = container.getUserData(key: accordionPaddingOffsetKey) ?? 0.0
        let delta: CGFloat = switch args.units.val {
            case .add(let unit): CGFloat(unit)
            case .subtract(let unit): -CGFloat(unit)
        }

        let newOffset = currentOffset + delta
        // Clamp: don't allow the offset to make the total padding negative.
        // The config padding is always >= 0, so clamping the offset at some reasonable floor
        // prevents negative total. We allow negative offsets (to shrink padding) but not
        // unboundedly — the layout code does max(0, padding + offset) anyway.
        container.putUserData(key: accordionPaddingOffsetKey, data: newOffset)
        return true
    }
}
