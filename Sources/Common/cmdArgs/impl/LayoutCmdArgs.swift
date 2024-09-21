public struct LayoutCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .layout,
        allowInConfig: true,
        help: layout_help_generated,
        options: [:],
        arguments: [newArgParser(\.toggleBetween, parseToggleBetween, mandatoryArgPlaceholder: LayoutDescription.unionLiteral)]
    )

    public var toggleBetween: Lateinit<[LayoutDescription]> = .uninitialized
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?

    public init(rawArgs: [String], toggleBetween: [LayoutDescription]) {
        self.rawArgs = .init(rawArgs)
        self.toggleBetween = .initialized(toggleBetween)
    }

    public enum LayoutDescription: String, CaseIterable, Equatable {
        case accordion, tiles
        case horizontal, vertical
        case h_accordion, v_accordion, h_tiles, v_tiles
        case tiling, floating
    }
}

private func parseToggleBetween(arg: String, _ nextArgs: inout [String]) -> Parsed<[LayoutCmdArgs.LayoutDescription]> {
    var args: [String] = nextArgs.allNextNonFlagArgs()
    args.insert(arg, at: 0)

    var result: [LayoutCmdArgs.LayoutDescription] = []
    for arg in args {
        if let layout = arg.parseLayoutDescription() {
            result.append(layout)
        } else {
            return .failure("Can't parse '\(arg)'\nPossible values: \(LayoutCmdArgs.LayoutDescription.unionLiteral)")
        }
    }

    return .success(result)
}

public func parseLayoutCmdArgs(_ args: [String]) -> ParsedCmd<LayoutCmdArgs> {
    parseSpecificCmdArgs(LayoutCmdArgs(rawArgs: args), args).map {
        check(!$0.toggleBetween.val.isEmpty)
        return $0
    }
}

private extension String {
    func parseLayoutDescription() -> LayoutCmdArgs.LayoutDescription? {
        if let parsed = LayoutCmdArgs.LayoutDescription(rawValue: self) {
            return parsed
        } else if self == "list" {
            return .tiles
        } else if self == "h_list" {
            return .h_tiles
        } else if self == "v_list" {
            return .v_tiles
        }
        return nil
    }
}
