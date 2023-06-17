import Foundation

extension Bundle {
    public static let appVersion: String = main.getInfo("CFBundleShortVersionString")
    private func getInfo(_ str: String) -> String { infoDictionary![str] as! String }
}
