extension DynamicConfigValue: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.constant(let lhsConstant), .constant(let rhsConstant)):
            return lhsConstant == rhsConstant
        case (.perMonitor(let lhsMonitors, let lhsDefaultValue), .perMonitor(let rhsMonitors, let rhsDefaultValue)):
            return lhsDefaultValue == rhsDefaultValue
                && lhsMonitors.count == rhsMonitors.count
                && zip(lhsMonitors, rhsMonitors).allSatisfy { $0.description == $1.description && $0.value == $1.value }
        default:
            return false
        }
    }
}
