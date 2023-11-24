struct VersionCommand: QueryCommand {
    func run() -> String {
        check(Thread.current.isMainThread)
        return "\(Bundle.appVersion) \(gitHash)"
    }
}
