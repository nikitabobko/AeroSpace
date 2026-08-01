import Foundation

final class AxWindowObserverContext {
    private struct Pending<Value> {
        let value: Value
        let expiresAtNs: UInt64
    }

    private let expirationNs: UInt64
    private let tolerance: CGFloat
    private var position: Pending<CGPoint>?
    private var size: Pending<CGSize>?

    init(expirationNs: UInt64 = 500_000_000, tolerance: CGFloat = 1) {
        self.expirationNs = expirationNs
        self.tolerance = tolerance
    }

    func prepareForPositionWrite() {
        position = nil
    }

    func prepareForSizeWrite() {
        size = nil
    }

    func clearExpectations() {
        position = nil
        size = nil
    }

    func recordPosition(_ value: CGPoint, nowNs: UInt64 = DispatchTime.now().uptimeNanoseconds) {
        position = Pending(value: value, expiresAtNs: nowNs + expirationNs)
    }

    func recordSize(_ value: CGSize, nowNs: UInt64 = DispatchTime.now().uptimeNanoseconds) {
        size = Pending(value: value, expiresAtNs: nowNs + expirationNs)
    }

    func shouldSuppressPositionNotification(
        isMouseDown: Bool,
        readActual: () -> CGPoint?,
        nowNs: UInt64 = DispatchTime.now().uptimeNanoseconds,
    ) -> Bool {
        guard !isMouseDown, hasExpectedPosition(nowNs: nowNs), let actual = readActual() else { return false }
        return matchesExpectedPosition(actual, nowNs: nowNs)
    }

    func shouldSuppressSizeNotification(
        isMouseDown: Bool,
        readActual: () -> CGSize?,
        nowNs: UInt64 = DispatchTime.now().uptimeNanoseconds,
    ) -> Bool {
        guard !isMouseDown, hasExpectedSize(nowNs: nowNs), let actual = readActual() else { return false }
        return matchesExpectedSize(actual, nowNs: nowNs)
    }

    private func hasExpectedPosition(nowNs: UInt64) -> Bool {
        if let position, nowNs >= position.expiresAtNs { self.position = nil }
        return position != nil
    }

    private func hasExpectedSize(nowNs: UInt64) -> Bool {
        if let size, nowNs >= size.expiresAtNs { self.size = nil }
        return size != nil
    }

    private func matchesExpectedPosition(_ actual: CGPoint, nowNs: UInt64) -> Bool {
        guard hasExpectedPosition(nowNs: nowNs), let expected = position?.value else { return false }
        let matches = abs(expected.x - actual.x) <= tolerance && abs(expected.y - actual.y) <= tolerance
        if !matches { position = nil }
        return matches
    }

    private func matchesExpectedSize(_ actual: CGSize, nowNs: UInt64) -> Bool {
        guard hasExpectedSize(nowNs: nowNs), let expected = size?.value else { return false }
        let matches = abs(expected.width - actual.width) <= tolerance && abs(expected.height - actual.height) <= tolerance
        if !matches { size = nil }
        return matches
    }

    static func fromRefcon(_ refcon: UnsafeMutableRawPointer?) -> AxWindowObserverContext? {
        unsafe refcon.map { unsafe Unmanaged<AxWindowObserverContext>.fromOpaque($0).takeUnretainedValue() }
    }
}
