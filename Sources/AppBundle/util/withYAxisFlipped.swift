import Foundation

extension CGRect {
    var withYAxisFlipped: Rect {
        let mainMonitorHeight: CGFloat = mainMonitorInfo.height
        let rect = toRect()
        return rect.with(\.topLeftY, mainMonitorHeight - rect.topLeftY)
    }
}

extension Point {
    var withYAxisFlipped: Point {
        consuming get {
            self.y = mainMonitorInfo.height - self.y
            return self
        }
    }
}
