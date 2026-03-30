public let stableAirlockAppId: String = "dev.airlock"
#if DEBUG
    public let airlockAppId: String = "dev.airlock.debug"
    public let airlockAppName: String = "Airlock-Debug"
#else
    public let airlockAppId: String = stableAirlockAppId
    public let airlockAppName: String = "Airlock"
#endif
