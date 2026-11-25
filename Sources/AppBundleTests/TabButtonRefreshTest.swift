@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct TabButtonRefreshTest {
    @Test func testTabTitleChangesDontCancelSlowRefreshSessions() async {
        let sessions = GatedRefreshSessions()
        let sleep = GatedSleep()
        let lastRefresh = ContinuousClock.now
        let throttle = TabButtonRefreshThrottle(now: { lastRefresh }, sleep: sleep.run)
        var scheduledSessions: [Task<(), any Error>] = []
        let scheduleRefreshSession = { scheduledSessions.append(scheduleCancellableRefreshSession(sessions.run)) }
        var titleChanges: [Task<(), Never>] = []
        func changeTitles() async {
            titleChanges.append(Task.startUnstructured { await throttle.schedule(scheduleRefreshSession) })
            await yieldUntil { throttle.isRefreshScheduled }
            for _ in 1 ..< 20 {
                titleChanges.append(Task.startUnstructured { await throttle.schedule(scheduleRefreshSession) })
            }
        }

        scheduleRefreshSession()
        await changeTitles()
        sessions.openGates(through: 1)
        await yieldUntil { sessions.log.contains("start 2") }

        await changeTitles()
        sleep.gate.open()
        sessions.openGates(through: 2)
        await yieldUntil { sessions.log.contains("start 3") }

        sessions.openGates(through: .max)
        for titleChange in titleChanges { await titleChange.value }
        for session in scheduledSessions { _ = await session.result }
        #expect(sessions.log == ["start 1", "end 1", "start 2", "end 2", "start 3", "end 3"])
        #expect(sleep.deadlines == [lastRefresh.advanced(by: .milliseconds(500))])
    }
}

@MainActor
private func yieldUntil(_ condition: () -> Bool) async {
    for _ in 0 ..< 1000 where !condition() { await Task.yield() }
}

@MainActor
private final class GatedRefreshSessions {
    private(set) var log: [String] = []
    private var gates: [Latch] = []
    private var openedThrough = 0

    func openGates(through session: Int) {
        openedThrough = session
        for gate in gates.prefix(session) { gate.open() }
    }

    func run() async {
        let gate = Latch()
        gates.append(gate)
        let session = gates.count
        if session <= openedThrough { gate.open() }
        log.append("start \(session)")
        await gate.wait()
        log.append(Task.isCancelled ? "cancel \(session)" : "end \(session)")
    }
}

@MainActor
private final class GatedSleep {
    let gate = Latch()
    private(set) var deadlines: [ContinuousClock.Instant] = []

    func run(until deadline: ContinuousClock.Instant) async {
        deadlines.append(deadline)
        await gate.wait()
    }
}

@MainActor
private final class Latch {
    private var isOpen = false
    private var waiters: [CheckedContinuation<(), Never>] = []

    func open() {
        isOpen = true
        for waiter in waiters { waiter.resume() }
        waiters = []
    }

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}
