public let stableAeroShiftAppId: String = "io.github.boredphilosopher96.aeroshift"
#if DEBUG
    public let aeroShiftAppId: String = "io.github.boredphilosopher96.aeroshift.debug"
    public let aeroShiftAppName: String = "AeroShift-Debug"
#else
    public let aeroShiftAppId: String = stableAeroShiftAppId
    public let aeroShiftAppName: String = "AeroShift"
#endif
