import Common
import Foundation

public func showMessageToUser(filename: String, message: String) {
    if isCli { // todo refactor. showMessageToUser is common code looks weird
        print(message)
    } else {
        let cachesDir = FileManager.default.homeDirectoryForCurrentUser.appending(component: "Library/Caches/bobko.aerospace/")
        try! FileManager.default.createDirectory(at: cachesDir, withIntermediateDirectories: true)
        let file = cachesDir.appending(component: filename)
        try! (message + "\n").write(to: file, atomically: false, encoding: .utf8)
        try! Process.run(URL(filePath: "/usr/bin/osascript"),
            arguments: [
                "-e",
                """
                tell app "Terminal"
                    activate
                    do script "less \(file.absoluteURL.path)"
                end tell
                """
            ]
        )
    }
}
