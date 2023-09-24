struct Rect {
    let topLeftX: CGFloat
    let topLeftY: CGFloat
    let width: CGFloat
    let height: CGFloat
}

extension [Rect] {
    func union() -> Rect {
        let rects: [Rect] = self
        let topLeftY = rects.map { $0.minY }.minOrThrow()
        let topLeftX = rects.map { $0.minX }.maxOrThrow()
        return Rect(
                topLeftX: topLeftX,
                topLeftY: topLeftY,
                width: rects.map { $0.maxX }.maxOrThrow() - topLeftX,
                height: rects.map { $0.maxY}.maxOrThrow() - topLeftY
        )
    }
}

extension CGRect {
    func monitorFrameNormalized() -> Rect {
        let mainMonitorHeight: CGFloat = NSScreen.screens.firstOrThrow { $0.isMainMonitor }.frame.height
        let rect = toRect()
        return rect.copy(topLeftY: mainMonitorHeight - rect.topLeftY)
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

    func copy(topLeftX: CGFloat? = nil, topLeftY: CGFloat? = nil, width: CGFloat? = nil, height: CGFloat? = nil) -> Rect {
        Rect(
                topLeftX: topLeftX ?? self.topLeftX,
                topLeftY: topLeftY ?? self.topLeftY,
                width: width ?? self.width,
                height: height ?? self.height
        )
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
}
