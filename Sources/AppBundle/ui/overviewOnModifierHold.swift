import AppKit
import Common

@MainActor private var flagsChangedMonitor: Any? = nil
@MainActor private var showTimer: Timer? = nil
@MainActor private var isOverviewShown = false

/// AeroSpace bindings are always 'modifier + key', so "hold a bare modifier" can't be expressed as a binding.
/// The modifier state is observed with a '.flagsChanged' monitor. Unlike a CGEventTap, it reports
/// modifier state only. It never sees which keys are pressed
@MainActor func syncOverviewOnModifierHold(_ config: Config) {
    if (config.overview.holdModifier != nil) == (flagsChangedMonitor != nil) {
        return
    }

    if config.overview.holdModifier == nil {
        NSEvent.removeMonitor(flagsChangedMonitor.orDie())
        flagsChangedMonitor = nil
        cancelOverview()
        return
    }

    flagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { @MainActor event in
        onModifiersChanged(event.modifierFlags)
    }
}

/// A binding was triggered, so the modifier is being used rather than rested on. Take the overview away and
/// start the countdown again, so that holding the modifier after e.g. 'alt-2' shows the new state
@MainActor func resetOverviewOnBindingTriggered() {
    cancelOverview()
    onModifiersChanged(NSEvent.modifierFlags)
}

@MainActor private func onModifiersChanged(_ flags: NSEvent.ModifierFlags) {
    guard let holdModifier = config.overview.holdModifier else { return }
    // Exact match. 'hold-modifier = alt' must not trigger on cmd-alt, otherwise the overview would pop up
    // in the middle of unrelated app shortcuts
    if flags.intersection(modifiersMask) != holdModifier {
        cancelOverview()
        return
    }
    if isOverviewShown || showTimer != nil { return }
    showTimer = .scheduledTimer(withTimeInterval: Double(config.overview.holdDelayMs) / 1000, repeats: false) { _ in
        Task.startUnstructured { @MainActor in
            showTimer = nil
            isOverviewShown = true
            OverviewPanel.shared.show()
        }
    }
}

@MainActor private func cancelOverview() {
    showTimer?.invalidate()
    showTimer = nil
    if isOverviewShown {
        isOverviewShown = false
        OverviewPanel.shared.hide()
    }
}

/// The modifiers that can appear in a binding. capsLock and fn must not break the exact match above
private let modifiersMask: NSEvent.ModifierFlags = [.shift, .control, .option, .command]
