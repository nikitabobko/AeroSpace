private let focusFollowsMouseParserTable: [String: any ParserProtocol<FocusFollowsMouse>] = [
    "enabled": Parser(\.enabled, parseBool),
]

func parseFocusFollowsMouse(_ rawConfig: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> FocusFollowsMouse {
    parseNonEmptyTable(rawConfig, FocusFollowsMouse(), focusFollowsMouseParserTable, backtrace, &c)
}
