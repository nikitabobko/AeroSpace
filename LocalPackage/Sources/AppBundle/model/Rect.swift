import AppKit
import Common

struct Rect: Copyable {
    var topLeftX: CGFloat
    var topLeftY: CGFloat
    var width: CGFloat
    var height: CGFloat
}

extension [Rect] {
    func union() -> Rect {
        let rects: [Rect] = self
        let topLeftY = rects.map(\.minY).minOrThrow()
        let topLeftX = rects.map(\.minX).maxOrThrow()
        return Rect(
                topLeftX: topLeftX,
                topLeftY: topLeftY,
                width: rects.map(\.maxX).maxOrThrow() - topLeftX,
                height: rects.map(\.maxY).maxOrThrow() - topLeftY
        )
    }
}

extension CGRect {
    func monitorFrameNormalized() -> Rect {
        let mainMonitorHeight: CGFloat = mainMonitor.height
        let rect = toRect()
        return rect.copy(\.topLeftY, mainMonitorHeight - rect.topLeftY)
    }
}

extension CGRect {
    func toRect() -> Rect {
        Rect(topLeftX: minX, topLeftY: maxY, width: width, height: height)
    }
}

extension Rect {
    func contains(_ point: CGPoint) -> Bool {
        let x = point.x
        let y = point.y
        return (minX..<maxX).contains(x) && (minY..<maxY).contains(y)
    }

    var center: CGPoint {
        CGPoint(x: topLeftX + width / 2, y: topLeftY + height / 2)
    }

    var topLeftCorner: CGPoint { CGPoint(x: topLeftX, y: topLeftY) }
    var topRightCorner: CGPoint { CGPoint(x: maxX, y: minY) }
    var bottomRightCorner: CGPoint { CGPoint(x: maxX, y: maxY) }
    var bottomLeftCorner: CGPoint { CGPoint(x: minX, y: maxY) }

    var minY: CGFloat { topLeftY }
    var maxY: CGFloat { topLeftY + height }
    var minX: CGFloat { topLeftX }
    var maxX: CGFloat { topLeftX + width }

    func getDimension(_ orientation: Orientation) -> CGFloat { orientation == .h ? width : height }
}
