struct VersionCommand: QueryCommand {
    @MainActor
    func run() -> String {
        check(Thread.current.isMainThread)
        return "\(Bundle.appVersion) \(gitHash)"
    }
}
