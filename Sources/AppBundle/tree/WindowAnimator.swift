import AppKit
import Common

let animationFrameIntervalMs = 16
let animationSlowStepThresholdMs = 40

struct FrameTarget: Equatable, Sendable {
    let topLeft: CGPoint?
    let size: CGSize?

    func resolve(against current: Rect) -> Rect {
        Rect(
            topLeftX: topLeft?.x ?? current.topLeftX,
            topLeftY: topLeft?.y ?? current.topLeftY,
            width: size?.width ?? current.width,
            height: size?.height ?? current.height,
        )
    }
}

struct FrameAnimation: Equatable, Sendable {
    var durationMs: Int
    var easing: Easing
    var startTopLeft: CGPoint? = nil
    var slideOut: WorkspaceSlide? = nil

    static let instant = FrameAnimation(durationMs: 0, easing: .linear)
}

extension Easing {
    func apply(_ t: Double) -> Double {
        let t = min(max(t, 0), 1)
        return switch self {
            case .linear: t
            case .easeOut: 1 - pow(1 - t, 3)
            case .easeInOut: t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
        }
    }
}

func animationProgress(elapsedNs: UInt64, durationMs: Int) -> Double {
    if durationMs <= 0 { return 1 }
    return min(Double(elapsedNs) / (Double(durationMs) * 1_000_000), 1)
}

func interpolateFrame(from: Rect, to: Rect, progress: Double) -> Rect {
    if progress <= 0 { return from }
    if progress >= 1 { return to }
    let p = CGFloat(progress)
    return Rect(
        topLeftX: from.topLeftX + (to.topLeftX - from.topLeftX) * p,
        topLeftY: from.topLeftY + (to.topLeftY - from.topLeftY) * p,
        width: from.width + (to.width - from.width) * p,
        height: from.height + (to.height - from.height) * p,
    )
}

func animationFrame(from: Rect, to: Rect, progress: Double, easing: Easing) -> Rect {
    progress >= 1 ? to : interpolateFrame(from: from, to: to, progress: easing.apply(progress))
}

func animationStartPlacement(startTopLeft: CGPoint?, size: CGSize?, wasInterrupted: Bool) -> FrameTarget? {
    guard let startTopLeft, !wasInterrupted else { return nil }
    return FrameTarget(topLeft: startTopLeft, size: size)
}

func tilingFrameDurationMs(isFullscreenTransition: Bool, resizeDurationMs: Int, fullscreenDurationMs: Int) -> Int {
    isFullscreenTransition ? fullscreenDurationMs : resizeDurationMs
}

enum SetFrameDecision: Equatable {
    case skip
    case instant
    case animate
}

func decideSetFrame(_ target: FrameTarget, durationMs: Int, lastTarget: FrameTarget?, isAnimatingToLastTarget: Bool) -> SetFrameDecision {
    if target == lastTarget && isAnimatingToLastTarget { return .skip }
    if durationMs <= 0 || target == lastTarget { return .instant }
    return .animate
}

final class AnimationCompletion: Sendable {
    nonisolated(unsafe) private var _isDone: Int32 = 0
    var isDone: Bool { unsafe _isDone == 1 }
    func markDone() {
        while !isDone {
            unsafe OSAtomicCompareAndSwapInt(0, 1, &_isDone)
        }
    }
}

struct FrameRequest {
    let target: FrameTarget
    let completion: AnimationCompletion?
}

private final class RunningFrameAnimation {
    let window: AXUIElement
    let from: Rect
    let to: Rect
    let target: FrameTarget
    let finalTarget: FrameTarget?
    let durationMs: Int
    let easing: Easing
    let job: RunLoopJob
    let completion: AnimationCompletion
    let startNs: UInt64 = DispatchTime.now().uptimeNanoseconds
    var timer: Timer? = nil

    init(
        window: AXUIElement,
        from: Rect,
        target: FrameTarget,
        finalTarget: FrameTarget?,
        animation: FrameAnimation,
        job: RunLoopJob,
        completion: AnimationCompletion,
    ) {
        self.window = window
        self.from = from
        self.to = target.resolve(against: from)
        self.target = target
        self.finalTarget = finalTarget
        self.durationMs = animation.durationMs
        self.easing = animation.easing
        self.job = job
        self.completion = completion
    }
}

final class AxFrameAnimator {
    private var lastSentFrames: [UInt32: Rect] = [:]
    private var running: [UInt32: RunningFrameAnimation] = [:]
    private var disabledAnimationsHolds = 0
    private var enhancedUserInterfaceWasEnabled = false

    func lastSentFrame(_ nativeWindowId: UInt32) -> Rect? { lastSentFrames[nativeWindowId] }

    func recordSent(_ nativeWindowId: UInt32, _ target: FrameTarget) {
        if let topLeft = target.topLeft, let size = target.size {
            lastSentFrames[nativeWindowId] = Rect(topLeftX: topLeft.x, topLeftY: topLeft.y, width: size.width, height: size.height)
        } else if let previous = lastSentFrames[nativeWindowId] {
            lastSentFrames[nativeWindowId] = target.resolve(against: previous)
        }
    }

    @discardableResult
    func stop(_ nativeWindowId: UInt32, app: AXUIElement) -> Bool {
        guard let animation = running.removeValue(forKey: nativeWindowId) else { return false }
        animation.timer?.invalidate()
        animation.completion.markDone()
        releaseDisabledAnimations(app)
        return true
    }

    func stopAll(app: AXUIElement) {
        for id in running.keys {
            stop(id, app: app)
        }
    }

    func prune(keeping alive: Set<UInt32>, app: AXUIElement) {
        for id in running.keys where !alive.contains(id) {
            stop(id, app: app)
        }
        lastSentFrames = lastSentFrames.filter { alive.contains($0.key) }
    }

    func start(
        _ nativeWindowId: UInt32,
        window: AXUIElement,
        app: AXUIElement,
        from: Rect,
        target: FrameTarget,
        finalTarget: FrameTarget?,
        animation: FrameAnimation,
        job: RunLoopJob,
        completion: AnimationCompletion,
        makeTimer: () -> Timer,
    ) {
        stop(nativeWindowId, app: app)
        let running = RunningFrameAnimation(
            window: window,
            from: from,
            target: target,
            finalTarget: finalTarget,
            animation: animation,
            job: job,
            completion: completion,
        )
        lastSentFrames[nativeWindowId] = from
        holdDisabledAnimations(app)
        self.running[nativeWindowId] = running
        let timer = makeTimer()
        running.timer = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    func tick(_ nativeWindowId: UInt32, app: AXUIElement) {
        guard let animation = running[nativeWindowId] else { return }
        if animation.job.isCancelled {
            stop(nativeWindowId, app: app)
            return
        }
        let stepStart = DispatchTime.now().uptimeNanoseconds
        let progress = animationProgress(elapsedNs: stepStart - animation.startNs, durationMs: animation.durationMs)
        send(nativeWindowId, animation, animationFrame(from: animation.from, to: animation.to, progress: progress, easing: animation.easing))
        let stepMs = Int((DispatchTime.now().uptimeNanoseconds - stepStart) / 1_000_000)
        if progress >= 1 {
            complete(nativeWindowId, animation, app: app)
        } else if stepMs > animationSlowStepThresholdMs {
            send(nativeWindowId, animation, animation.to)
            complete(nativeWindowId, animation, app: app)
        }
    }

    private func complete(_ nativeWindowId: UInt32, _ animation: RunningFrameAnimation, app: AXUIElement) {
        if let finalTarget = animation.finalTarget {
            try? setFrame(animation.window, finalTarget.topLeft, finalTarget.size, animation.job)
            recordSent(nativeWindowId, finalTarget)
        }
        stop(nativeWindowId, app: app)
    }

    private func send(_ nativeWindowId: UInt32, _ animation: RunningFrameAnimation, _ frame: Rect) {
        let target = FrameTarget(
            topLeft: animation.target.topLeft != nil ? frame.topLeftCorner : nil,
            size: animation.target.size != nil ? frame.size : nil,
        )
        try? setFrame(animation.window, target.topLeft, target.size, animation.job)
        recordSent(nativeWindowId, target)
    }

    private func holdDisabledAnimations(_ app: AXUIElement) {
        if disabledAnimationsHolds == 0 {
            enhancedUserInterfaceWasEnabled = app.get(Ax.enhancedUserInterfaceAttr) == true
            if enhancedUserInterfaceWasEnabled {
                app.set(Ax.enhancedUserInterfaceAttr, false)
            }
        }
        disabledAnimationsHolds += 1
    }

    private func releaseDisabledAnimations(_ app: AXUIElement) {
        disabledAnimationsHolds -= 1
        if disabledAnimationsHolds == 0 && enhancedUserInterfaceWasEnabled {
            app.set(Ax.enhancedUserInterfaceAttr, true)
            enhancedUserInterfaceWasEnabled = false
        }
    }
}
