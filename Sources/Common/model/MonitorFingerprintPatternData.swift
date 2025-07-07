public struct MonitorFingerprintPatternData: Equatable, Sendable {
    public let vendorID: UInt32?
    public let modelID: UInt32?
    public let serialNumber: String?
    public let displayNamePattern: String?
    public let widthPixels: Int?
    public let heightPixels: Int?

    public init(
        vendorID: UInt32? = nil,
        modelID: UInt32? = nil,
        serialNumber: String? = nil,
        displayNamePattern: String? = nil,
        widthPixels: Int? = nil,
        heightPixels: Int? = nil
    ) {
        self.vendorID = vendorID
        self.modelID = modelID
        self.serialNumber = serialNumber
        self.displayNamePattern = displayNamePattern
        self.widthPixels = widthPixels
        self.heightPixels = heightPixels
    }
}
