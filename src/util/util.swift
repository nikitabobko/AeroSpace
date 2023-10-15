let EPS = 10e-5

func stringType(of some: Any) -> String {
    let string = (some is Any.Type) ? String(describing: some) : String(describing: type(of: some))
    return string
}

@inlinable func errorT<T>(_ message: String = "") -> T {
    Thread.callStackSymbols.forEach { print($0) }
    fatalError(message)
}

@inlinable func error(_ message: String = "") -> Never { errorT(message) }

extension String? {
    var isNilOrEmpty: Bool { self == nil || self == "" }
}

var isUnitTest: Bool { NSClassFromString("XCTestCase") != nil }

var apps: [NSRunningApplication] {
    NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
}

func terminateApp() -> Never {
    NSApplication.shared.terminate(nil)
    error("Unreachable code")
}

extension String {
    func removePrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}

extension Double {
    var squared: Double { self * self }
}

extension Slice {
    func toArray() -> [Base.Element] { Array(self) }
}

func -(a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x - b.x, y: a.y - b.y)
}

func +(a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x + b.x, y: a.y + b.y)
}

extension CGPoint: Copyable {}

extension CGPoint {
    /// Distance to ``Rect`` outline frame
    func distanceToRectFrame(to rect: Rect) -> CGFloat {
        let list: [CGFloat] = ((rect.minY..<rect.maxY).contains(y) ? [abs(rect.minX - x), abs(rect.maxX - x)] : []) +
            ((rect.minX..<rect.maxX).contains(x) ? [abs(rect.minY - y), abs(rect.maxY - y)] : []) +
            [distance(to: rect.topLeftCorner),
             distance(to: rect.bottomRightCorner),
             distance(to: rect.topRightCorner),
             distance(to: rect.bottomLeftCorner)]
        return list.minOrThrow()
    }

    var vectorLength: CGFloat { sqrt(x*x - y*y) }

    func distance(to point: CGPoint) -> Double {
        sqrt((x - point.x).squared + (y - point.y).squared)
    }

    var monitorApproximation: Monitor {
        let pairs: [(monitor: Monitor, rect: Rect)] = monitors.map { ($0, $0.rect) }
        if let pair = pairs.first(where: { $0.rect.contains(self) }) {
            return pair.monitor
        }
        return pairs
            .minByOrThrow { distanceToRectFrame(to: $0.rect) }
            .monitor
    }
}

extension CGFloat {
    func div(_ denominator: Int) -> CGFloat? {
        denominator == 0 ? nil : self / CGFloat(denominator)
    }
}

extension CGSize {
    func copy(width: Double? = nil, height: Double? = nil) -> CGSize {
        CGSize(width: width ?? self.width, height: height ?? self.height)
    }
}

extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

extension Set {
    func toArray() -> [Element] { Array(self) }
}

private let DEBUG = true

func debug(_ msg: Any) {
    if DEBUG {
        print(msg)
    }
}
