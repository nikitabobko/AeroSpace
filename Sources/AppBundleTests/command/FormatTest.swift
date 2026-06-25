@testable import AppBundle
import Common
import Foundation
import XCTest

private func assertPrimitive(_ actual: Result<Primitive, InterVarExpansionError>, _ expected: Primitive, file: StaticString = #filePath, line: UInt = #line) {
    switch actual {
        case .failure: failExpectedActual("Result.success(\(expected.toString()))", actual, file: file, line: line)
        case .success(let primitive):
            if primitive.kind != expected.kind || primitive.toString() != expected.toString() {
                failExpectedActual("\(expected.kind.rawValue)(\(expected.toString()))", "\(primitive.kind.rawValue)(\(primitive.toString()))", file: file, line: line)
            }
    }
}

@MainActor
final class FormatTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testAeroObjKind() {
        let window = TestWindow.new(id: 1, parent: Workspace.get(byName: name).rootTilingContainer)
        let workspace = Workspace.get(byName: name)
        assertEquals(AeroObj.window(.forTest(window: window, title: nil)).kind, .window)
        assertEquals(AeroObj.workspace(workspace).kind, .workspace)
        assertEquals(AeroObj.app(TestApp.shared).kind, .app)
        assertEquals(AeroObj.monitor(mainMonitor).kind, .monitor)
    }

    func testResolveWindowForFormatVarPrefetchesTitleOnlyWhenNeeded() async throws {
        let window = TestWindow.new(id: 7, parent: Workspace.get(byName: name).rootTilingContainer)
        let withTitle = try await WindowWithPrefetchedTitle.resolveWindow(window, for: .window(.windowTitle), .nonCancellable)
        assertEquals(withTitle.title, "TestWindow(7)")

        let withoutTitle = try await WindowWithPrefetchedTitle.resolveWindow(window, for: .window(.windowId), .nonCancellable)
        assertNil(withoutTitle.title)
    }

    func testResolveWindowForFormatTokensPrefetchesTitleOnlyWhenNeeded() async throws {
        let window = TestWindow.new(id: 3, parent: Workspace.get(byName: name).rootTilingContainer)

        let withTitle = try await WindowWithPrefetchedTitle.resolveWindow(window, for: [
            .literal("foo"),
            .interVar(.formatVar(.window(.windowTitle))),
        ], .nonCancellable)
        assertEquals(withTitle.title, "TestWindow(3)")

        let withoutTitle = try await WindowWithPrefetchedTitle.resolveWindow(window, for: [
            .interVar(.formatVar(.window(.windowId))),
            .interVar(.plainInterVar(.newline)),
        ], .nonCancellable)
        assertNil(withoutTitle.title)
    }

    func testFormatEmptyInput() {
        let result: [AeroObj] = []
        assertSucc(result.format([.interVar(.formatVar(.window(.windowId)))]), [])
    }

    func testFormatWithNewlineAndTab() {
        let window = TestWindow.new(id: 42, parent: Workspace.get(byName: name).rootTilingContainer)
        let objs: [AeroObj] = [.window(.forTest(window: window, title: nil))]
        let result = objs.format([
            .interVar(.formatVar(.window(.windowId))),
            .interVar(.plainInterVar(.tab)),
            .literal("X"),
            .interVar(.plainInterVar(.newline)),
            .literal("end"),
        ])
        assertSucc(result, ["42\tX\nend"])
    }

    func testFormatMultipleRightPaddingColumns() {
        Workspace.get(byName: name).rootTilingContainer.apply {
            let windows: [AeroObj] = [
                .window(.forTest(window: TestWindow.new(id: 2, parent: $0), title: "a")),
                .window(.forTest(window: TestWindow.new(id: 100, parent: $0), title: "bb")),
            ]
            let result = windows.format([
                .interVar(.formatVar(.window(.windowId))),
                .interVar(.plainInterVar(.rightPadding)),
                .literal(" | "),
                .interVar(.formatVar(.window(.windowTitle))),
                .interVar(.plainInterVar(.rightPadding)),
                .literal(" END"),
            ])
            assertSucc(result, [
                "2   | a  END",
                "100 | bb END",
            ])
        }
    }

    func testFormatFailureAccumulatesErrors() {
        let workspace = Workspace.get(byName: name)
        let objs: [AeroObj] = [.workspace(workspace)]
        let result = objs.format([
            .interVar(.formatVar(.window(.windowId))),
            .interVar(.plainInterVar(.rightPadding)),
            .interVar(.formatVar(.window(.windowTitle))),
        ])
        switch result {
            case .success: XCTFail("expected failure")
            case .failure(let msg):
                let msg = msg.map(\.description).joined(separator: "\n")
                assertTrue(msg.contains("Unknown interpolation variable 'window-id'"))
                assertTrue(msg.contains("Unknown interpolation variable 'window-title'"))
        }
    }

    func testPrimitiveKind() {
        assertEquals(Primitive.bool(true).kind, .bool)
        assertEquals(Primitive.int(7).kind, .int)
        assertEquals(Primitive.string("x").kind, .string)
    }

    func testPrimitiveToString() {
        assertEquals(Primitive.bool(true).toString(), "true")
        assertEquals(Primitive.bool(false).toString(), "false")
        assertEquals(Primitive.int(42).toString(), "42")
        assertEquals(Primitive.string("hello").toString(), "hello")
    }

    func testPrimitiveIntConvenienceConstructors() {
        assertEquals(Primitive.int(UInt32(5)).toString(), "5")
        assertEquals(Primitive.int(Int32(-3)).toString(), "-3")
        assertEquals(Primitive.int(Int(123)).toString(), "123")
    }

    func testPrimitiveEncoding() throws {
        let cases: [(Primitive, String)] = [
            (.bool(true), "true"),
            (.bool(false), "false"),
            (.int(42), "42"),
            (.string("hi"), "\"hi\""),
        ]
        for (primitive, expected) in cases {
            let data = try JSONEncoder().encode(primitive)
            assertEquals(String(data: data, encoding: .utf8), expected)
        }
    }

    func testPrimitiveKindRawValues() {
        assertEquals(Primitive.Kind.bool.rawValue, "Bool")
        assertEquals(Primitive.Kind.int.rawValue, "Int")
        assertEquals(Primitive.Kind.string.rawValue, "String")
    }

    func testExpandWindowIdAndIsFullscreen() {
        let window = TestWindow.new(id: 9, parent: Workspace.get(byName: name).rootTilingContainer)
        window.isFullscreen = true
        let obj = AeroObj.window(.forTest(window: window, title: "title-x"))

        assertPrimitive(FormatVar.window(.windowId).expandFormatVar(obj: obj), .int(Int64(9)))
        assertPrimitive(FormatVar.window(.windowIsFullscreen).expandFormatVar(obj: obj), .bool(true))
        assertPrimitive(FormatVar.window(.windowTitle).expandFormatVar(obj: obj), .string("title-x"))
    }

    func testExpandWindowLayoutTiling() {
        let root = Workspace.get(byName: name).rootTilingContainer
        let window = TestWindow.new(id: 1, parent: root)
        let obj = AeroObj.window(.forTest(window: window, title: nil))

        root.layout = .tiles
        root.changeOrientation(.h)
        assertPrimitive(FormatVar.window(.windowLayout).expandFormatVar(obj: obj), .string("h_tiles"))
        assertPrimitive(FormatVar.window(.windowParentContainerLayout).expandFormatVar(obj: obj), .string("h_tiles"))

        root.layout = .accordion
        assertPrimitive(FormatVar.window(.windowLayout).expandFormatVar(obj: obj), .string("h_accordion"))

        root.changeOrientation(.v)
        assertPrimitive(FormatVar.window(.windowLayout).expandFormatVar(obj: obj), .string("v_accordion"))

        root.layout = .tiles
        assertPrimitive(FormatVar.window(.windowLayout).expandFormatVar(obj: obj), .string("v_tiles"))
    }

    func testExpandWindowLayoutFloating() {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.floatingWindowsContainer)
        let obj = AeroObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.window(.windowLayout).expandFormatVar(obj: obj), .string("floating"))
    }

    func testExpandWindowLayoutMacosNativeFullscreen() {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.macOsNativeFullscreenWindowsContainer)
        let obj = AeroObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.window(.windowLayout).expandFormatVar(obj: obj), .string("macos_native_fullscreen"))
    }

    func testExpandWindowLayoutMacosNativeHiddenApp() {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.macOsNativeHiddenAppsWindowsContainer)
        let obj = AeroObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.window(.windowLayout).expandFormatVar(obj: obj), .string("macos_native_window_of_hidden_app"))
    }

    func testExpandWindowLayoutMacosNativeMinimized() {
        let window = TestWindow.new(id: 1, parent: macosMinimizedWindowsContainer)
        let obj = AeroObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.window(.windowLayout).expandFormatVar(obj: obj), .string("macos_native_minimized"))
    }

    func testExpandWindowLayoutMacosPopup() {
        let window = TestWindow.new(id: 1, parent: macosPopupWindowsContainer)
        let obj = AeroObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.window(.windowLayout).expandFormatVar(obj: obj), .string("NULL-WINDOW-LAYOUT"))
    }

    func testExpandWindowToWorkspaceWhenWindowHasWorkspace() {
        let window = TestWindow.new(id: 1, parent: Workspace.get(byName: name).rootTilingContainer)
        let obj = AeroObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.workspace(.workspaceName).expandFormatVar(obj: obj), .string(name))
    }

    func testExpandWindowToWorkspaceWhenWindowDetached() {
        let window = TestWindow.new(id: 1, parent: Workspace.get(byName: name).rootTilingContainer)
        window.unbindFromParent()
        let obj = AeroObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.workspace(.workspaceName).expandFormatVar(obj: obj), .string("NULL-WORKSPACE"))
    }

    func testExpandWindowToMonitorWhenWindowHasMonitor() {
        let window = TestWindow.new(id: 1, parent: Workspace.get(byName: name).rootTilingContainer)
        let obj = AeroObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.monitor(.monitorName).expandFormatVar(obj: obj), .string(mainMonitor.name))
    }

    func testExpandWindowToMonitorWhenWindowDetached() {
        let window = TestWindow.new(id: 1, parent: Workspace.get(byName: name).rootTilingContainer)
        window.unbindFromParent()
        let obj = AeroObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.monitor(.monitorName).expandFormatVar(obj: obj), .string("NULL-MONITOR"))
    }

    func testExpandWindowToApp() {
        let window = TestWindow.new(id: 1, parent: Workspace.get(byName: name).rootTilingContainer)
        let obj = AeroObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.app(.appPid).expandFormatVar(obj: obj), .int(Int64(0)))
        assertPrimitive(FormatVar.app(.appBundleId).expandFormatVar(obj: obj), .string("bobko.AeroSpace.test-app"))
    }

    func testExpandWorkspaceVars() {
        let workspace = Workspace.get(byName: name)
        assertTrue(workspace.focusWorkspace())
        let obj = AeroObj.workspace(workspace)
        assertPrimitive(FormatVar.workspace(.workspaceName).expandFormatVar(obj: obj), .string(name))
        assertPrimitive(FormatVar.workspace(.workspaceFocused).expandFormatVar(obj: obj), .bool(true))
        assertPrimitive(FormatVar.workspace(.workspaceVisible).expandFormatVar(obj: obj), .bool(true))
        assertPrimitive(FormatVar.workspace(.workspaceRootContainerLayout).expandFormatVar(obj: obj), .string("h_tiles"))
    }

    func testExpandWorkspaceFocusedAndVisibleForOtherWorkspace() {
        let other = Workspace.get(byName: "other")
        let obj = AeroObj.workspace(other)
        assertPrimitive(FormatVar.workspace(.workspaceFocused).expandFormatVar(obj: obj), .bool(false))
        assertPrimitive(FormatVar.workspace(.workspaceVisible).expandFormatVar(obj: obj), .bool(false))
    }

    func testExpandWorkspaceToMonitor() {
        let workspace = Workspace.get(byName: name)
        let obj = AeroObj.workspace(workspace)
        assertPrimitive(FormatVar.monitor(.monitorName).expandFormatVar(obj: obj), .string(mainMonitor.name))
        assertPrimitive(FormatVar.monitor(.monitorIsMain).expandFormatVar(obj: obj), .bool(true))
    }

    func testExpandMonitorVars() {
        let monitor = mainMonitor
        let obj = AeroObj.monitor(monitor)
        assertPrimitive(FormatVar.monitor(.monitorAppKitNsScreenScreensId).expandFormatVar(obj: obj), .int(Int64(monitor.monitorAppKitNsScreenScreensId)))
        assertPrimitive(FormatVar.monitor(.monitorName).expandFormatVar(obj: obj), .string(monitor.name))
        assertPrimitive(FormatVar.monitor(.monitorIsMain).expandFormatVar(obj: obj), .bool(true))
        assertPrimitive(FormatVar.monitor(.monitorId_oneBased).expandFormatVar(obj: obj), .int(Int64(1)))
    }

    func testExpandAppVars() {
        let obj = AeroObj.app(TestApp.shared)
        assertPrimitive(FormatVar.app(.appBundleId).expandFormatVar(obj: obj), .string("bobko.AeroSpace.test-app"))
        assertPrimitive(FormatVar.app(.appName).expandFormatVar(obj: obj), .string("bobko.AeroSpace.test-app"))
        assertPrimitive(FormatVar.app(.appPid).expandFormatVar(obj: obj), .int(Int64(0)))
        assertPrimitive(FormatVar.app(.appExecPath).expandFormatVar(obj: obj), .string("NULL-APP-EXEC-PATH"))
        assertPrimitive(FormatVar.app(.appBundlePath).expandFormatVar(obj: obj), .string("NULL-APP-BUNDLE-PATH"))
    }

    func testPlainInterVarExpand() {
        assertPrimitive(PlainInterVar.newline.expandFormatVar(), .string("\n"))
        assertPrimitive(PlainInterVar.tab.expandFormatVar(), .string("\t"))
    }

    func testInterVarExpandDelegates() {
        let window = TestWindow.new(id: 5, parent: Workspace.get(byName: name).rootTilingContainer)
        let obj = AeroObj.window(.forTest(window: window, title: nil))

        assertPrimitive(InterVar.formatVar(.window(.windowId)).expandFormatVar(obj: obj), .int(Int64(5)))
        assertPrimitive(InterVar.plainInterVar(.newline).expandFormatVar(obj: obj), .string("\n"))
    }

    func testUnknownInterpolationVariableMessage() {
        let workspace = AeroObj.workspace(Workspace.get(byName: name))
        let msg = unknownInterpolationVariable(variable: "bogus", workspace)
        assertTrue(msg.starts(with: "Unknown interpolation variable 'bogus'."))
        assertTrue(msg.contains("Possible values:"))
        // Workspace kind should include workspace + monitor vars + plain inter vars.
        assertTrue(msg.contains("workspace"))
        assertTrue(msg.contains("monitor-name"))
        assertTrue(msg.contains("right-padding"))
    }

    func testFormatToJsonEmptyInput() {
        let result: [AeroObj] = []
        assertSucc(
            result.formatToJson([.interVar(.formatVar(.window(.windowId)))], ignoreRightPaddingVar: true),
            JSONEncoder.aeroSpaceDefault.encodeToString([[String: Primitive]]()).orDie(),
        )
    }

    func testFormatToJsonSingleObject() {
        let window = TestWindow.new(id: 42, parent: Workspace.get(byName: name).rootTilingContainer)
        window.isFullscreen = true
        let objs: [AeroObj] = [.window(.forTest(window: window, title: "hello"))]
        let result = objs.formatToJson(
            [
                .interVar(.formatVar(.window(.windowId))),
                .interVar(.formatVar(.window(.windowTitle))),
                .interVar(.formatVar(.window(.windowIsFullscreen))),
            ],
            ignoreRightPaddingVar: true,
        )
        let expected = JSONEncoder.aeroSpaceDefault.encodeToString([[
            "window-id": Primitive.int(42),
            "window-title": Primitive.string("hello"),
            "window-is-fullscreen": Primitive.bool(true),
        ]])
        assertSucc(result, expected.orDie())
    }

    func testFormatToJsonMultipleObjects() {
        Workspace.get(byName: name).rootTilingContainer.apply {
            let objs: [AeroObj] = [
                .window(.forTest(window: TestWindow.new(id: 1, parent: $0), title: nil)),
                .window(.forTest(window: TestWindow.new(id: 2, parent: $0), title: nil)),
            ]
            let result = objs.formatToJson(
                [.interVar(.formatVar(.window(.windowId)))],
                ignoreRightPaddingVar: true,
            )
            let expected = JSONEncoder.aeroSpaceDefault.encodeToString([
                ["window-id": Primitive.int(1)],
                ["window-id": Primitive.int(2)],
            ])
            assertSucc(result, expected.orDie())
        }
    }

    func testFormatToJsonIgnoresLiterals() {
        let window = TestWindow.new(id: 7, parent: Workspace.get(byName: name).rootTilingContainer)
        let objs: [AeroObj] = [.window(.forTest(window: window, title: nil))]
        let result = objs.formatToJson(
            [
                .literal("ignored-prefix"),
                .interVar(.formatVar(.window(.windowId))),
                .literal("  "),
            ],
            ignoreRightPaddingVar: true,
        )
        let expected = JSONEncoder.aeroSpaceDefault.encodeToString([["window-id": Primitive.int(7)]])
        assertSucc(result, expected.orDie())
    }

    func testFormatToJsonIgnoresRightPaddingWhenFlagTrue() {
        let window = TestWindow.new(id: 8, parent: Workspace.get(byName: name).rootTilingContainer)
        let objs: [AeroObj] = [.window(.forTest(window: window, title: nil))]
        let result = objs.formatToJson(
            [
                .interVar(.formatVar(.window(.windowId))),
                .interVar(.plainInterVar(.rightPadding)),
            ],
            ignoreRightPaddingVar: true,
        )
        let expected = JSONEncoder.aeroSpaceDefault.encodeToString([["window-id": Primitive.int(8)]])
        assertSucc(result, expected.orDie())
    }

    func testFormatToJsonRightPaddingFailsWhenFlagFalse() {
        let window = TestWindow.new(id: 8, parent: Workspace.get(byName: name).rootTilingContainer)
        let objs: [AeroObj] = [.window(.forTest(window: window, title: nil))]
        let result = objs.formatToJson(
            [
                .interVar(.formatVar(.window(.windowId))),
                .interVar(.plainInterVar(.rightPadding)),
            ],
            ignoreRightPaddingVar: false,
        )
        assertFail(result, "'right-padding' interpolation variable cannot be expanded")
    }

    func testFormatToJsonExpandsPlainInterVars() {
        let window = TestWindow.new(id: 11, parent: Workspace.get(byName: name).rootTilingContainer)
        let objs: [AeroObj] = [.window(.forTest(window: window, title: nil))]
        let result = objs.formatToJson(
            [
                .interVar(.formatVar(.window(.windowId))),
                .interVar(.plainInterVar(.newline)),
                .interVar(.plainInterVar(.tab)),
            ],
            ignoreRightPaddingVar: true,
        )
        let expected = JSONEncoder.aeroSpaceDefault.encodeToString([[
            "window-id": Primitive.int(11),
            "newline": Primitive.string("\n"),
            "tab": Primitive.string("\t"),
        ]])
        assertSucc(result, expected.orDie())
    }

    func testFormatToJsonFailsOnUnknownInterpolationVariable() {
        let objs: [AeroObj] = [.workspace(Workspace.get(byName: name))]
        let result = objs.formatToJson(
            [.interVar(.formatVar(.window(.windowId)))],
            ignoreRightPaddingVar: true,
        )
        switch result {
            case .success: XCTFail("expected failure")
            case .failure(let msg):
                assertTrue(msg.starts(with: "Unknown interpolation variable 'window-id'."))
        }
    }

    func testFormatToJsonReturnsFirstFailureForMultipleObjects() {
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
        }
        let objs: [AeroObj] = [
            .workspace(Workspace.get(byName: name)),
            .workspace(Workspace.get(byName: "other")),
        ]
        let result = objs.formatToJson(
            [.interVar(.formatVar(.window(.windowId)))],
            ignoreRightPaddingVar: true,
        )
        assertFail(result)
    }

    func testFormatToJsonOverlappingKeysKeepLastValue() {
        let window = TestWindow.new(id: 5, parent: Workspace.get(byName: name).rootTilingContainer)
        window.isFullscreen = false
        let objs: [AeroObj] = [.window(.forTest(window: window, title: nil))]
        let result = objs.formatToJson(
            [
                .interVar(.formatVar(.window(.windowIsFullscreen))),
                .literal(" between literals "),
                .interVar(.formatVar(.window(.windowIsFullscreen))),
            ],
            ignoreRightPaddingVar: true,
        )
        let expected = JSONEncoder.aeroSpaceDefault.encodeToString([[
            "window-is-fullscreen": Primitive.bool(false),
        ]])
        assertSucc(result, expected.orDie())
    }
}
