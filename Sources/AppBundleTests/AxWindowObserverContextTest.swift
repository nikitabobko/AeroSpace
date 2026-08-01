@testable import AppBundle
import AppKit
import XCTest

final class AxWindowObserverContextTest: XCTestCase {
    func testDuplicatePositionNotificationsMatchWithinToleranceUntilExpiration() {
        let context = AxWindowObserverContext(expirationNs: 100, tolerance: 1)
        context.recordPosition(CGPoint(x: 10, y: 20), nowNs: 10)

        assertTrue(context.shouldSuppressPositionNotification(isMouseDown: false, readActual: { CGPoint(x: 11, y: 19) }, nowNs: 20))
        assertTrue(context.shouldSuppressPositionNotification(isMouseDown: false, readActual: { CGPoint(x: 10, y: 20) }, nowNs: 30))
        assertFalse(context.shouldSuppressPositionNotification(isMouseDown: false, readActual: { CGPoint(x: 10, y: 20) }, nowNs: 110))
    }

    func testDuplicateSizeNotificationsMatch() {
        let context = AxWindowObserverContext(expirationNs: 100)
        context.recordSize(CGSize(width: 800, height: 600), nowNs: 10)

        assertTrue(context.shouldSuppressSizeNotification(isMouseDown: false, readActual: { CGSize(width: 800, height: 600) }, nowNs: 20))
        assertTrue(context.shouldSuppressSizeNotification(isMouseDown: false, readActual: { CGSize(width: 800, height: 600) }, nowNs: 30))
    }

    func testPositionMismatchClearsExpectation() {
        let context = AxWindowObserverContext(expirationNs: 100, tolerance: 1)
        context.recordPosition(CGPoint(x: 10, y: 20), nowNs: 10)

        assertFalse(context.shouldSuppressPositionNotification(isMouseDown: false, readActual: { CGPoint(x: 11.01, y: 20) }, nowNs: 20))
        assertFalse(context.shouldSuppressPositionNotification(isMouseDown: false, readActual: { CGPoint(x: 10, y: 20) }, nowNs: 30))
    }

    func testSizeAndPositionAreIndependent() {
        let context = AxWindowObserverContext(expirationNs: 100)
        context.recordPosition(CGPoint(x: 10, y: 20), nowNs: 10)
        context.recordSize(CGSize(width: 800, height: 600), nowNs: 10)

        assertTrue(context.shouldSuppressSizeNotification(isMouseDown: false, readActual: { CGSize(width: 800, height: 600) }, nowNs: 20))
        assertFalse(context.shouldSuppressPositionNotification(isMouseDown: false, readActual: { CGPoint(x: 12, y: 20) }, nowNs: 20))
        assertTrue(context.shouldSuppressSizeNotification(isMouseDown: false, readActual: { CGSize(width: 800, height: 600) }, nowNs: 30))

        context.recordPosition(CGPoint(x: 10, y: 20), nowNs: 40)
        context.recordSize(CGSize(width: 800, height: 600), nowNs: 40)
        assertFalse(context.shouldSuppressSizeNotification(isMouseDown: false, readActual: { CGSize(width: 802, height: 600) }, nowNs: 50))
        assertTrue(context.shouldSuppressPositionNotification(isMouseDown: false, readActual: { CGPoint(x: 10, y: 20) }, nowNs: 50))
    }

    func testNewestWriteReplacesPreviousValueAndMismatchClearsIt() {
        let context = AxWindowObserverContext(expirationNs: 100)
        context.recordSize(CGSize(width: 800, height: 600), nowNs: 10)
        context.recordSize(CGSize(width: 900, height: 700), nowNs: 20)

        assertTrue(context.shouldSuppressSizeNotification(isMouseDown: false, readActual: { CGSize(width: 900, height: 700) }, nowNs: 25))
        assertFalse(context.shouldSuppressSizeNotification(isMouseDown: false, readActual: { CGSize(width: 800, height: 600) }, nowNs: 30))
        assertFalse(context.shouldSuppressSizeNotification(isMouseDown: false, readActual: { CGSize(width: 900, height: 700) }, nowNs: 40))
    }

    func testMouseDownAndFailedReadDoNotConsumeExpectation() {
        let context = AxWindowObserverContext(expirationNs: 100)
        context.recordSize(CGSize(width: 800, height: 600), nowNs: 10)

        var didRead = false
        assertFalse(context.shouldSuppressSizeNotification(isMouseDown: true, readActual: {
            didRead = true
            return CGSize(width: 800, height: 600)
        }, nowNs: 20))
        assertFalse(didRead)
        assertFalse(context.shouldSuppressSizeNotification(isMouseDown: false, readActual: { nil }, nowNs: 30))
        assertTrue(context.shouldSuppressSizeNotification(isMouseDown: false, readActual: { CGSize(width: 800, height: 600) }, nowNs: 40))
    }

    func testPreparingForFailedWriteClearsStaleExpectation() {
        let context = AxWindowObserverContext(expirationNs: 100)
        context.recordPosition(CGPoint(x: 10, y: 20), nowNs: 10)
        context.recordSize(CGSize(width: 800, height: 600), nowNs: 10)

        context.prepareForPositionWrite()
        context.prepareForSizeWrite()

        assertFalse(context.shouldSuppressPositionNotification(isMouseDown: false, readActual: { CGPoint(x: 10, y: 20) }, nowNs: 20))
        assertFalse(context.shouldSuppressSizeNotification(isMouseDown: false, readActual: { CGSize(width: 800, height: 600) }, nowNs: 20))
    }

    func testCancellationClearsAllExpectations() {
        let context = AxWindowObserverContext(expirationNs: 100)
        context.recordPosition(CGPoint(x: 10, y: 20), nowNs: 10)
        context.recordSize(CGSize(width: 800, height: 600), nowNs: 10)

        context.clearExpectations()

        assertFalse(context.shouldSuppressPositionNotification(isMouseDown: false, readActual: { CGPoint(x: 10, y: 20) }, nowNs: 20))
        assertFalse(context.shouldSuppressSizeNotification(isMouseDown: false, readActual: { CGSize(width: 800, height: 600) }, nowNs: 20))
    }
}
