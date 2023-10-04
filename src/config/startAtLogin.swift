func syncStartAtLogin() {
    let url: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/LaunchAgents/\(Bundle.appId).plist")
    if config.startAtLogin {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(Bundle.appId)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(URL(filePath: CommandLine.arguments.first ?? errorT("Can't get first argument")).absoluteString)</string>
                <string>--started-at-login</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """
        (try? plist.write(to: url, atomically: true, encoding: .utf8)) ?? errorT("Can't write to \(url)")
        // todo try!
        try! Process.run(URL(filePath: "/bin/launchctl"), arguments: ["load", url.absoluteString])
    } else {
        // todo try!
        try! Process.run(URL(filePath: "/bin/launchctl"), arguments: ["unload", url.absoluteString])
        try? FileManager.default.removeItem(at: url)
    }
}
