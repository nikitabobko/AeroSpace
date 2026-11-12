@testable import AppBundle
import AppKit
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct NativeFullscreenSettlingTest {
    init() {
        setUpWorkspacesForTests()
        config.automaticallyUnhideMacosHiddenApps = true
        for window in macosPopupWindowsContainer.children + macosMinimizedWindowsContainer.children { window.unbindFromParent() }
    }

    private func frame(_ workspace: Workspace, now: ContinuousClock.Instant = .now) async throws {
        try await normalizeLayoutReason()
        workspace.normalizeContainers()
        try await settleNativeFullscreenRestorations(now: now)
        try await workspace.layoutWorkspace()
    }

    private func restoredPair() async throws -> (Workspace, TestWindow, TestWindow) {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.changeOrientation(.v)
        let browser = TestWindow.new(id: 1, parent: root, adaptiveWeight: 900)
        let terminal = TestWindow.new(id: 2, parent: root, adaptiveWeight: 150)
        #expect(browser.focusWindow())
        try await workspace.layoutWorkspace()
        browser.isMacosFullscreenForTest = true
        try await frame(workspace)
        browser.isMacosFullscreenForTest = false
        try await frame(workspace)
        #expect(hasNativeFullscreenSettling(browser))
        return (workspace, browser, terminal)
    }

    @Test func testSettlingEndsAfterStableFrames() async throws {
        let (workspace, browser, _) = try await restoredPair()
        let now = ContinuousClock.now
        try await frame(workspace, now: now)
        try await frame(workspace, now: now.advanced(by: .milliseconds(299)))
        #expect(hasNativeFullscreenSettling(browser))
        try await frame(workspace, now: now.advanced(by: .milliseconds(301)))
        #expect(!hasNativeFullscreenSettling(browser))
    }

    @Test func testLateVisibilityRestartsSettlingClock() async throws {
        let (workspace, browser, terminal) = try await restoredPair()
        let height = browser.getWeight(.v)
        let now = ContinuousClock.now
        try await frame(workspace, now: now)
        terminal.lifeStatus = .invisible
        try await frame(workspace, now: now.advanced(by: .milliseconds(200)))
        terminal.lifeStatus = .alive
        try await frame(workspace, now: now.advanced(by: .milliseconds(250)))
        #expect(abs(browser.getWeight(.v) - height) < 0.001)
        try await frame(workspace, now: now.advanced(by: .milliseconds(350)))
        try await frame(workspace, now: now.advanced(by: .milliseconds(600)))
        #expect(hasNativeFullscreenSettling(browser))
        try await frame(workspace, now: now.advanced(by: .milliseconds(651)))
        #expect(!hasNativeFullscreenSettling(browser))
    }

    @Test func testDelayedNativeResizeIsReapplied() async throws {
        let (workspace, browser, _) = try await restoredPair()
        let rect = try await browser.getAxRect(.nonCancellable)!
        let now = ContinuousClock.now
        try await frame(workspace, now: now)
        browser.setAxFrame(nil, CGSize(width: rect.width, height: rect.height + 50))
        try await frame(workspace, now: now.advanced(by: .milliseconds(200)))
        #expect(hasNativeFullscreenSettling(browser))
        #expect(try await browser.getAxSize(.nonCancellable)?.height == rect.height)
    }

    @Test(arguments: ["resize height +40", "balance-sizes", "layout floating", "move-node-to-workspace other"])
    func testUserCommandsCancelProtection(command: String) async throws {
        let (workspace, browser, _) = try await restoredPair()
        let result = await parseCommand(command).cmdOrDie.run(.defaultEnv.withWindowId(browser.windowId), .emptyStdin)
        #expect(result.exitCode.rawValue == 0)
        #expect(!hasNativeFullscreenSettling(browser))
        let size = try await browser.getAxSize(.nonCancellable)
        try await frame(workspace)
        if command == "resize height +40" {
            #expect(try await browser.getAxSize(.nonCancellable)?.height == (size?.height ?? 0) + 40)
        }
    }

    @Test func testMouseResizeInvalidatesBeforeChangingWeights() async throws {
        let (workspace, browser, terminal) = try await restoredPair()
        let height = browser.getWeight(.v)
        // The mouse resize handler calls this before modifying weights.
        resetClosedWindowsCache()
        browser.setWeight(.v, height + 40)
        terminal.setWeight(.v, terminal.getWeight(.v) - 40)
        try await frame(workspace)
        #expect(!hasNativeFullscreenSettling(browser))
        #expect(abs(browser.getWeight(.v) - height - 40) < 0.001)
    }

    @Test func testLayoutCommandInvalidatesBeforeItsBodyRuns() async throws {
        let (_, browser, _) = try await restoredPair()
        let result = await SettlingMutationProbe(windowId: browser.windowId).run(.defaultEnv, .emptyStdin)
        #expect(result.exitCode.rawValue == 0)
    }

    @Test func testChangedTreeCancelsWithoutReorderingWindows() async throws {
        let (workspace, browser, terminal) = try await restoredPair()
        terminal.bind(to: workspace.rootTilingContainer, adaptiveWeight: 150, index: 0)
        try await frame(workspace)
        #expect(!hasNativeFullscreenSettling(browser))
        #expect(workspace.rootTilingContainer.children.first === terminal)
    }

    @Test func testNewFullscreenCycleCancelsOldProtection() async throws {
        let (workspace, browser, _) = try await restoredPair()
        browser.isMacosFullscreenForTest = true
        try await frame(workspace)
        #expect(!hasNativeFullscreenSettling(browser))
        #expect(browser.parent === workspace.macOsNativeFullscreenWindowsContainer)
        browser.isMacosFullscreenForTest = false
        try await frame(workspace)
        #expect(hasNativeFullscreenSettling(browser))
    }

    @Test func testProtectionExpiresWithoutStableVisibility() async throws {
        let (workspace, browser, terminal) = try await restoredPair()
        terminal.lifeStatus = .invisible
        try await frame(workspace, now: .now.advanced(by: .seconds(4)))
        #expect(!hasNativeFullscreenSettling(browser))
        #expect(browser.layoutReason == .standard)
    }

    @Test func testChangedAvailableHeightKeepsNormalLayoutAdjustment() async throws {
        let (_, browser, terminal) = try await restoredPair()
        let parent = browser.parent!
        let height = browser.getWeight(.v)
        parent.lastAppliedLayoutPhysicalRect!.height += 20
        browser.setWeight(.v, height + 10)
        terminal.setWeight(.v, terminal.getWeight(.v) + 10)
        try await settleNativeFullscreenRestorations()
        #expect(abs(browser.getWeight(.v) - height - 10) < 0.001)
    }

    @Test func testClosedWindowReleasesProtection() async throws {
        let (workspace, browser, _) = try await restoredPair()
        browser.closeAxWindow()
        try await frame(workspace)
        #expect(!hasNativeFullscreenSettling(browser))
    }
}

private struct SettlingMutationProbe: Command {
    let args = TrueCmdArgs(rawArgs: [])
    let shouldResetClosedWindowsCache = true
    let windowId: OpaqueWindowId

    @MainActor func run(_ env: CmdEnv, _ io: CmdIo) async -> ConditionalExitCode {
        guard let window = Window.get(byId: windowId) else { return ._false }
        return hasNativeFullscreenSettling(window) ? ._false : ._true
    }
}
