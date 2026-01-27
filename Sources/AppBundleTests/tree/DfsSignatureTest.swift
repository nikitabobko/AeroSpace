@testable import AppBundle
import XCTest

@MainActor
final class DfsSignatureTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
    }

    func testGetDfsSignature_emptyWorkspace() {
        let workspace = Workspace.get(byName: "test")

        let signature = workspace.getDfsSignature()

        XCTAssertEqual(signature, "C[h]()")
    }

    func testGetDfsSignature_singleWindow() {
        let workspace = Workspace.get(byName: "test")
        TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        let signature = workspace.getDfsSignature()

        XCTAssertEqual(signature, "C[h](W:1)")
    }

    func testGetDfsSignature_twoWindowsHorizontal() {
        let workspace = Workspace.get(byName: "test")
        TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        TestWindow.new(id: 2, parent: workspace.rootTilingContainer)

        let signature = workspace.getDfsSignature()

        XCTAssertEqual(signature, "C[h](W:1,W:2)")
    }

    func testGetDfsSignature_twoWindowsVertical() {
        let workspace = Workspace.get(byName: "test")
        workspace.rootTilingContainer.changeOrientation(.v)
        TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        TestWindow.new(id: 2, parent: workspace.rootTilingContainer)

        let signature = workspace.getDfsSignature()

        XCTAssertEqual(signature, "C[v](W:1,W:2)")
    }

    func testGetDfsSignature_nestedContainers() {
        let workspace = Workspace.get(byName: "test")
        TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let verticalContainer = TilingContainer.newVTiles(
            parent: workspace.rootTilingContainer,
            adaptiveWeight: 1,
        )
        TestWindow.new(id: 2, parent: verticalContainer)
        TestWindow.new(id: 3, parent: verticalContainer)

        let signature = workspace.getDfsSignature()

        XCTAssertEqual(signature, "C[h](W:1,C[v](W:2,W:3))")
    }

    func testDfsSignature_changesWhenWindowAdded() {
        let workspace = Workspace.get(byName: "test")
        TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        let signatureBefore = workspace.getDfsSignature()
        XCTAssertEqual(signatureBefore, "C[h](W:1)")

        TestWindow.new(id: 2, parent: workspace.rootTilingContainer)

        let signatureAfter = workspace.getDfsSignature()
        XCTAssertEqual(signatureAfter, "C[h](W:1,W:2)")
        XCTAssertNotEqual(signatureBefore, signatureAfter)
    }

    func testDfsSignature_changesWhenWindowRemoved() {
        let workspace = Workspace.get(byName: "test")
        TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let window2 = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)

        let signatureBefore = workspace.getDfsSignature()
        XCTAssertEqual(signatureBefore, "C[h](W:1,W:2)")

        window2.unbindFromParent()
        let signatureAfter = workspace.getDfsSignature()
        XCTAssertEqual(signatureAfter, "C[h](W:1)")
        XCTAssertNotEqual(signatureBefore, signatureAfter)
    }

    func testDfsSignature_changesWhenWindowOrderChanges() {
        let workspace = Workspace.get(byName: "test")
        let window1 = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        TestWindow.new(id: 2, parent: workspace.rootTilingContainer)

        let signatureBefore = workspace.getDfsSignature()
        XCTAssertEqual(signatureBefore, "C[h](W:1,W:2)")

        window1.unbindFromParent()
        window1.bind(to: workspace.rootTilingContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        let signatureAfter = workspace.getDfsSignature()
        XCTAssertEqual(signatureAfter, "C[h](W:2,W:1)")
        XCTAssertNotEqual(signatureBefore, signatureAfter)
    }

    func testGetDfsSignature_threeWindows() {
        let workspace = Workspace.get(byName: "test")
        TestWindow.new(id: 100, parent: workspace.rootTilingContainer)
        TestWindow.new(id: 200, parent: workspace.rootTilingContainer)
        TestWindow.new(id: 300, parent: workspace.rootTilingContainer)

        let signature = workspace.getDfsSignature()

        XCTAssertEqual(signature, "C[h](W:100,W:200,W:300)")
    }

    func testGetDfsSignature_complexNested() {
        let workspace = Workspace.get(byName: "test")
        TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let verticalContainer = TilingContainer.newVTiles(
            parent: workspace.rootTilingContainer,
            adaptiveWeight: 1,
        )
        TestWindow.new(id: 2, parent: verticalContainer)
        let horizontalContainer = TilingContainer.newHTiles(
            parent: verticalContainer,
            adaptiveWeight: 1,
        )
        TestWindow.new(id: 3, parent: horizontalContainer)
        TestWindow.new(id: 4, parent: horizontalContainer)

        let signature = workspace.getDfsSignature()

        XCTAssertEqual(signature, "C[h](W:1,C[v](W:2,C[h](W:3,W:4)))")
    }

    func testDfsSignature_changesWhenOrientationChanges() {
        let workspace = Workspace.get(byName: "test")
        TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        TestWindow.new(id: 2, parent: workspace.rootTilingContainer)

        let signatureBefore = workspace.getDfsSignature()
        XCTAssertEqual(signatureBefore, "C[h](W:1,W:2)")

        workspace.rootTilingContainer.changeOrientation(.v)
        let signatureAfter = workspace.getDfsSignature()
        XCTAssertEqual(signatureAfter, "C[v](W:1,W:2)")
        XCTAssertNotEqual(signatureBefore, signatureAfter)
    }
}
