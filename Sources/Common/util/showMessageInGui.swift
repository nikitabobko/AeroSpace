import Foundation

// todo refactor. showMessageInGui in common code looks weird
public func showMessageInGui(filenameIfConsoleApp: String, title: String, message: String) {
    let titleAndMessage = "##### \(title) #####\n\n" + message
    if isCli {
        print(titleAndMessage)
    } else {
        let cachesDir = URL(filePath: "/tmp/bobko.aerospace/")
        Result { try FileManager.default.createDirectory(at: cachesDir, withIntermediateDirectories: true) }.getOrDie()
        let file = cachesDir.appending(component: filenameIfConsoleApp)
        Result { try (titleAndMessage + "\n").write(to: file, atomically: true, encoding: .utf8) }.getOrDie()

        file.absoluteURL.open(with: URL(filePath: "/System/Applications/Utilities/Console.app"))
    }
}
