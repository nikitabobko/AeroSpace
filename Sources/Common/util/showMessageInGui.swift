import Foundation

// todo refactor. showMessageInGui is common code looks weird
public func showMessageInGui(filenameIfConsoleApp: String?, title: String, message: String) {
    let titleAndMessage = "##### \(title) #####\n\n" + message
    if isCli {
        print(titleAndMessage)
    } else if let filenameIfConsoleApp {
        let cachesDir = URL(filePath: "/tmp/bobko.aerospace/")
        try! FileManager.default.createDirectory(at: cachesDir, withIntermediateDirectories: true)
        let file = cachesDir.appending(component: filenameIfConsoleApp)
        try! (titleAndMessage + "\n").write(to: file, atomically: true, encoding: .utf8)

        file.absoluteURL.open(with: URL(filePath: "/System/Applications/Utilities/Console.app"))
    } else {
        try! Process.run(URL(filePath: "/usr/bin/osascript"),
            arguments: [
                "-e",
                """
                display dialog "\(message)" with title "\(title)"
                """
            ]
        )
        // === Alternatives ===
        // let myPopup = NSAlert()
        // myPopup.messageText = message
        // myPopup.alertStyle = NSAlert.Style.informational
        // myPopup.addButton(withTitle: "OK")
        // myPopup.runModal()

        // let alert = UIAlertController(title: "Alert", message: message, preferredStyle: UIAlertControllerStyle.alert)
        // alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.default, handler: nil))
        // self.present(alert, animated: true, completion: nil)

        // file.absoluteURL.open(with: URL(filePath: "/System/Applications/Utilities/Console.app"))
        // file.absoluteURL.open(with: URL(filePath: "/System/Applications/TextEdit.app"))
    }
}
