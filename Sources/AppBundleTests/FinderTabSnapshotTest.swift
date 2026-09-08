@testable import AppBundle
import AppKit
import XCTest

final class FinderTabSnapshotTest: XCTestCase {
    private let frame = CGRect(x: 20, y: 40, width: 800, height: 600)

    func testOpeningFirstTabPreservesSlot() {
        XCTAssertTrue(FinderTabSnapshot(members: [1, 2], frame: frame)
            .matches(FinderTabSnapshot(members: [], frame: frame)))
    }

    func testClosingLastExtraTabPreservesSlot() {
        XCTAssertTrue(FinderTabSnapshot(members: [], frame: frame)
            .matches(FinderTabSnapshot(members: [1, 2], frame: frame)))
    }

    func testTabIdentitySurvivesFrameChanges() {
        XCTAssertTrue(FinderTabSnapshot(members: [2, 3], frame: .zero)
            .matches(FinderTabSnapshot(members: [1, 2], frame: frame)))
    }

    func testSeparateWindowsAndMissingFramesDoNotMatch() {
        XCTAssertFalse(FinderTabSnapshot(members: [], frame: frame)
            .matches(FinderTabSnapshot(members: [], frame: frame)))
        XCTAssertFalse(FinderTabSnapshot(members: [3, 4], frame: .zero)
            .matches(FinderTabSnapshot(members: [1, 2], frame: frame)))
        XCTAssertFalse(FinderTabSnapshot(members: [3, 4], frame: nil)
            .matches(FinderTabSnapshot(members: [1, 2], frame: nil)))
    }
}
