import CoreFoundation

struct Point: Hashable {
    public var x: CGFloat = 0
    public var y: CGFloat = 0

    static let zero = Point()

    var asCGPoint: CGPoint { CGPoint(x: x, y: y) }
}

extension CGPoint {
    var asMyPoint: Point { Point(x: x, y: y) }
}
