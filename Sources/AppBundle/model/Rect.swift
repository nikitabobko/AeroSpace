import AppKit
import Common

struct Rect: Withable, AeroAny {
    var topLeftX: CGFloat
    var topLeftY: CGFloat

    private var _width: CGFloat
    var width: CGFloat {
        get { max(_width, 0) }
        set(newValue) { _width = newValue }
    }

    private var _height: CGFloat
    var height: CGFloat {
        get { max(_height, 0) }
        set(newValue) { _height = newValue }
    }

    init(topLeftX: CGFloat, topLeftY: CGFloat, width: CGFloat, height: CGFloat) {
        self.topLeftX = topLeftX
        self.topLeftY = topLeftY
        self._width = width
        self._height = height
    }
}

extension CGRect {
    func toRect() -> Rect {
        Rect(topLeftX: minX, topLeftY: maxY, width: width, height: height)
    }
}

extension Rect {
    func contains(_ point: Point) -> Bool {
        minX.until(excl: maxX)?.contains(point.x) == true && minY.until(excl: maxY)?.contains(point.y) == true
    }

    var center: Point {
        Point(x: topLeftX + width / 2, y: topLeftY + height / 2)
    }

    var topLeftCorner: Point { Point(x: topLeftX, y: topLeftY) }
    // periphery:ignore
    var topRightCorner: Point { Point(x: maxX, y: minY) }
    var bottomRightCorner: Point { Point(x: maxX, y: maxY) }
    var bottomLeftCorner: Point { Point(x: minX, y: maxY) }

    var minY: CGFloat { topLeftY }
    var maxY: CGFloat { topLeftY + height }
    var minX: CGFloat { topLeftX }
    var maxX: CGFloat { topLeftX + width }

    var size: CGSize { CGSize(width: width, height: height) }

    func getDimension(_ orientation: Orientation) -> CGFloat { orientation == .h ? width : height }
}
