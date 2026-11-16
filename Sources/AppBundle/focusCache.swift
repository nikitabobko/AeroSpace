import Common

@MainActor private var lastKnownNativeFocusedWindowId: OpaqueWindowId? = nil
@MainActor private var nativeFocusTransaction: NativeFocusTransaction? = nil
@MainActor private var nativeFocusReassertionTask: Task<Void, Never>? = nil
@MainActor private var nextNativeFocusTransactionId: UInt64 = 0

private let nativeFocusSettlingDuration = Duration.milliseconds(250)
private let nativeFocusReassertionDelay = Duration.milliseconds(100)

@MainActor
private struct NativeFocusTransaction {
    let id: UInt64
    let target: Window
    var acknowledged = false
    var correctionAttempts = 0
    var deadline: ContinuousClock.Instant
}

/// Keep AeroSpace focus authoritative while an explicit macOS focus request settles.
///
/// An app can first acknowledge the requested window, then publish its previous
/// window as focused a few milliseconds later. A rapid workspace switch can
/// also let an older native-focus request surface after the newest request.
/// The transaction remains active through those late events. A newer focus
/// request replaces the transaction immediately.
@MainActor func expectNativeFocus(_ window: Window) {
    nativeFocusReassertionTask?.cancel()
    nativeFocusReassertionTask = nil
    nextNativeFocusTransactionId += 1
    nativeFocusTransaction = NativeFocusTransaction(
        id: nextNativeFocusTransactionId,
        target: window,
        deadline: ContinuousClock.now + nativeFocusSettlingDuration,
    )
}

@MainActor
private func scheduleNativeFocusReassertion(for transaction: NativeFocusTransaction) {
    guard transaction.correctionAttempts == 0, nativeFocusReassertionTask == nil else { return }
    nativeFocusReassertionTask = Task { @MainActor in
        do {
            try await Task.sleep(for: nativeFocusReassertionDelay)
        } catch {
            return
        }
        guard var current = nativeFocusTransaction,
              current.id == transaction.id,
              current.deadline > .now
        else {
            return
        }
        nativeFocusReassertionTask = nil
        current.correctionAttempts += 1
        current.acknowledged = false
        current.deadline = ContinuousClock.now + nativeFocusSettlingDuration
        nativeFocusTransaction = current
        current.target.nativeFocus()
    }
}

/// The data should flow (from nativeFocused to focused) and
///                      (from nativeFocused to lastKnownNativeFocusedWindowId)
/// Alternative names: takeFocusFromMacOs, syncFocusFromMacOs
@MainActor func updateFocusCache(_ nativeFocused: Window?) {
    if nativeFocused?.parent is MacosPopupWindowsContainer {
        return
    }
    if var transaction = nativeFocusTransaction {
        if transaction.deadline <= .now {
            nativeFocusTransaction = nil
        } else if nativeFocused == transaction.target {
            transaction.acknowledged = true
            transaction.deadline = ContinuousClock.now + nativeFocusSettlingDuration
            nativeFocusTransaction = transaction
            lastKnownNativeFocusedWindowId = nativeFocused?.windowId
            (nativeFocused as? MacWindow)?.macApp.lastFocusedNativeWindowOpaqueId = nativeFocused?.windowId
            return
        } else if nativeFocused == nil {
            return
        } else {
            if transaction.acknowledged {
                scheduleNativeFocusReassertion(for: transaction)
            }
            return
        }
    }
    if nativeFocused?.windowId != lastKnownNativeFocusedWindowId {
        _ = nativeFocused?.focusWindow()
        lastKnownNativeFocusedWindowId = nativeFocused?.windowId
    }
    (nativeFocused as? MacWindow)?.macApp.lastFocusedNativeWindowOpaqueId = nativeFocused?.windowId
}
