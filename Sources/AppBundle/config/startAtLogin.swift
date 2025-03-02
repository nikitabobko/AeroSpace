import AppKit
import Common

@MainActor
func syncStartAtLogin() {
    let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser.appending(component: "Library/LaunchAgents/")
    Result { try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true) }.getOrThrow()
    let url: URL = launchAgentsDir.appending(path: "bobko.aerospace.plist")
    if config.startAtLogin {
        let plist =
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>\(aeroSpaceAppId)</string>
                <key>ProgramArguments</key>
                <array>
                    <string>\(URL(filePath: CommandLine.arguments.first ?? errorT("Can't get first argument")).absoluteURL.path)</string>
                    <string>--started-at-login</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
            </dict>
            </plist>
            """
        if plist != (try? String(contentsOf: url)) {
            Result { try plist.write(to: url, atomically: false, encoding: .utf8) }.getOrThrow("Can't write to \(url) ")
        }
    } else {
        try? FileManager.default.removeItem(at: url)
    }
}
