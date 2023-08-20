import Foundation

extension Bundle {
    public static let appVersion: String = main.getInfo("CFBundleShortVersionString")
    public static let appName: String = main.getInfo("CFBundleName")
    private func getInfo(_ str: String) -> String { infoDictionary![str] as! String }
}
