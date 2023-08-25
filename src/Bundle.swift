import Foundation

extension Bundle {
    public static let appVersion: String = main.getInfo("CFBundleShortVersionString")
    public static let appName: String = main.getInfo("CFBundleName")
    public static let appId: String = main.getInfo("CFBundleIdentifier") // e.g. bobko.AeroSpace or bobko.debug.AeroSpace
    private func getInfo(_ str: String) -> String { infoDictionary![str] as! String }
}
