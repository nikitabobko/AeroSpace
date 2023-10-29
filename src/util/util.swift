let EPS = 10e-5

func stringType(of some: Any) -> String {
    let string = (some is Any.Type) ? String(describing: some) : String(describing: type(of: some))
    return string
}

func check(
    _ condition: Bool,
    _ message: String = "",
    file: String = #file,
    line: Int = #line,
    column: Int = #column,
    function: String = #function
) {
    if !condition {
        error(message, file: file, line: line, column: column, function: function)
    }
}

private var recursionDetectorDuringFailure: Bool = false

public func errorT<T>(
    _ message: String = "",
    file: String = #file,
    line: Int = #line,
    column: Int = #column,
    function: String = #function
) -> T {
    let message =
        """
        ###############################
        ### AEROSPACE RUNTIME ERROR ###
        ###############################

        Please report to:
            https://github.com/nikitabobko/AeroSpace/issues/new

        Message: \(message)
        Version: \(Bundle.appVersion)
        Git hash: \(gitHash)
        Coordinate: \(file):\(line):\(column) \(function)
        recursionDetectorDuringFailure: \(recursionDetectorDuringFailure)

        Stacktrace:
        \(Thread.callStackSymbols.joined(separator: "\n"))
        """
    if !isUnitTest {
        showMessageToUser(
            filename: recursionDetectorDuringFailure ? "runtime-error-recursion.txt" : "runtime-error.txt",
            message: message
        )
    }
    if !recursionDetectorDuringFailure {
        recursionDetectorDuringFailure = true
        makeAllWindowsVisibleAndRestoreSize()
    }
    fatalError(message)
}

@inlinable func error(
    _ message: String = "",
    file: String = #file,
    line: Int = #line,
    column: Int = #column,
    function: String = #function
) -> Never {
    errorT(message, file: file, line: line, column: column, function: function)
}

public func makeAllWindowsVisibleAndRestoreSize() {
    for app in apps { // Make all windows fullscreen before Quit
        for window in app.windows {
            // makeAllWindowsVisibleAndRestoreSize may be invoked when something went wrong (e.g. some windows are unbound)
            // that's why it's not allowed to use `.parent` call in here
            let monitor = window.getCenter()?.monitorApproximation ?? mainMonitor
            window.setTopLeftCorner(monitor.rect.topLeftCorner)
            window.setSize(window.lastFloatingSize
                ?? CGSize(width: monitor.visibleRect.width, height: monitor.visibleRect.height))
        }
    }
}

var allMonitorsRectsUnion: Rect {
    monitors.map(\.rect).union()
}

extension String? {
    var isNilOrEmpty: Bool { self == nil || self == "" }
}

public var isUnitTest: Bool { NSClassFromString("XCTestCase") != nil }

var apps: [AeroApp] {
    isUnitTest
        ? (appForTests?.lets { [$0] } ?? [])
        : NSWorkspace.shared.runningApplications.lazy.filter { $0.activationPolicy == .regular }.map(\.macApp).filterNotNil()
}

func terminateApp() -> Never {
    NSApplication.shared.terminate(nil)
    error("Unreachable code")
}

extension String {
    func removePrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }

    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(self, forType: .string)
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

    func coerceIn(rect: Rect) -> CGPoint {
        CGPoint(x: x.coerceIn(rect.minX...(rect.maxX - 1)), y: y.coerceIn(rect.minY...(rect.maxY - 1)))
    }

    func addingXOffset(_ offset: CGFloat) -> CGPoint { CGPoint(x: x + offset, y: y) }
    func addingYOffset(_ offset: CGFloat) -> CGPoint { CGPoint(x: x, y: y + offset) }

    func getProjection(_ orientation: Orientation) -> Double { orientation == .h ? x : y }

    var vectorLength: CGFloat { sqrt(x*x - y*y) }

    func distance(to point: CGPoint) -> Double {
        sqrt((x - point.x).squared + (y - point.y).squared)
    }

    var monitorApproximation: Monitor {
        let monitors = monitors
        return monitors.first(where: { $0.rect.contains(self) })
            ?? monitors.minByOrThrow { distanceToRectFrame(to: $0.rect) }
    }
}

extension CGFloat {
    func div(_ denominator: Int) -> CGFloat? {
        denominator == 0 ? nil : self / CGFloat(denominator)
    }

    func coerceIn(_ range: ClosedRange<CGFloat>) -> CGFloat {
        if self > range.upperBound {
            return range.upperBound
        } else if self < range.lowerBound {
            return range.lowerBound
        } else {
            return self
        }
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
