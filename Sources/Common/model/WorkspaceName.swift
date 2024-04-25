public struct WorkspaceName: Equatable {
    public let raw: String

    private init(_ raw: String) {
        self.raw = raw
    }

    public static func parse(_ raw: String) -> Parsed<WorkspaceName> {
        // reserved names
        if raw == "focused" || raw == "non-focused" ||
                raw == "visible" || raw == "invisible" || raw == "non-visible" ||
                raw == "active" || raw == "non-active" || raw == "inactive" ||
                raw == "back-and-forth" || raw == "back_and_forth" || raw == "previous" ||
                raw == "prev" || raw == "next" ||
                raw == "monitor" || raw == "workspace" ||
                raw == "monitors" || raw == "workspaces" ||
                raw == "all" || raw == "none" ||
                raw == "mouse" {
            return .failure("'\(raw)' is a reserved workspace name")
        }
        if raw.contains(",") {
            return .failure("Workspace names are not allowed to contain comma")
        }
        if raw.starts(with: "_") {
            return .failure("Workspace names starting with underscore are reserved for future use")
        }
        if raw.starts(with: "-") {
            // The syntax conflicts with CLI options. E.g. list-windows --workspace -foo
            return .failure("Workspace names starting with dash are disallowed")
        }
        if raw.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            return .failure("Whitespace characters are forbidden in workspace names")
        }
        return .success(WorkspaceName(raw))
    }
}
