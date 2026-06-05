public let stableAeroSpaceAppId: String = "sh.saad.flightdeck"
#if DEBUG
    public let aeroSpaceAppId: String = "sh.saad.flightdeck.debug"
    public let aeroSpaceAppName: String = "FlightDeck-Debug"
#else
    public let aeroSpaceAppId: String = stableAeroSpaceAppId
    public let aeroSpaceAppName: String = "FlightDeck"
#endif
