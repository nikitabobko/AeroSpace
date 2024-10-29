import Common
import Foundation

public let configDotfileName = isDebug ? ".aerospace-debug.toml" : ".aerospace.toml"
public func findCustomConfigUrl() -> ConfigFile {
    let fileName = isDebug ? "aerospace-debug.toml" : "aerospace.toml"
    let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]?.lets { URL(filePath: $0) }
        ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/")
    let candidates: [URL] = if let configLocation = serverArgs.configLocation {
        [URL(filePath: configLocation)]
    } else {
        [
            FileManager.default.homeDirectoryForCurrentUser.appending(path: configDotfileName),
            xdgConfigHome.appending(path: "aerospace").appending(path: fileName),
        ]
    }
    let existingCandidates: [URL] = candidates.filter { (candidate: URL) in FileManager.default.fileExists(atPath: candidate.path) }
    let count = existingCandidates.count
    return switch count {
        case 0: .noCustomConfigExists
        case 1: .file(existingCandidates.first!)
        default: .ambiguousConfigError(existingCandidates)
    }
}

public enum ConfigFile {
    case file(URL), ambiguousConfigError(_ candidates: [URL]), noCustomConfigExists

    public var urlOrNil: URL? {
        return switch self {
            case .file(let url): url
            case .ambiguousConfigError, .noCustomConfigExists: nil
        }
    }
}
