import Foundation

extension CGRect {
    var withYAxisFlipped: Rect {
        let mainMonitorHeight: CGFloat = mainMonitorInfo.height
        let rect = toRect()
        return rect.copy(\.topLeftY, mainMonitorHeight - rect.topLeftY)
    }
}

extension CGPoint {
    var withYAxisFlipped: CGPoint {
        consuming get {
            self.y = mainMonitorInfo.height - self.y
            return self
        }
    }
}
