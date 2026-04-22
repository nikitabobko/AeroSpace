public let stableAeroshiftAppId: String = "io.github.boredphilosopher96.aeroshift"
#if DEBUG
    public let aeroshiftAppId: String = "io.github.boredphilosopher96.aeroshift.debug"
    public let aeroshiftAppName: String = "Aeroshift-Debug"
#else
    public let aeroshiftAppId: String = stableAeroshiftAppId
    public let aeroshiftAppName: String = "Aeroshift"
#endif
