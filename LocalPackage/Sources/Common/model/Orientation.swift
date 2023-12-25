public enum Orientation {
    /// Windows are planced along the **horizontal** line
    /// x-axis
    case h
    /// Windows are planced along the **vertical** line
    /// y-axis
    case v
}

public extension Orientation {
    var opposite: Orientation { self == .h ? .v : .h }
}
