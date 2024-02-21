import Common

extension Bundle {
    public static let appVersion: String = main.getInfo("CFBundleShortVersionString")
    public static let appName: String = main.getInfo("CFBundleName")
    public static let bundleId: String = main.getInfo("CFBundleIdentifier") // e.g. bobko.aerospace.1 or bobko.debug.aerospace
    private func getInfo(_ str: String) -> String { infoDictionary![str] as! String }
}

let appId: String = isDebug ? "bobko.debug.aerospace" : "bobko.aerospace"
