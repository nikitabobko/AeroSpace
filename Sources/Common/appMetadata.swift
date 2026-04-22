public let stableAeroSpaceAppId: String = "io.github.boredphilosopher96.aeroshift"
#if DEBUG
    public let aeroSpaceAppId: String = "io.github.boredphilosopher96.aeroshift.debug"
    public let aeroSpaceAppName: String = "AeroShift-Debug"
#else
    public let aeroSpaceAppId: String = stableAeroSpaceAppId
    public let aeroSpaceAppName: String = "AeroShift"
#endif
