/// Syntax:
/// layout (main|h_accordion|v_accordion|h_list|v_list|floating|tiling)...
struct LayoutCommand: Command {
    let toggleTo: [Layout]
    enum Layout {
        case main
        case h_accordion
        case v_accordion
        case h_list
        case v_list
        case floating
    }

    func run() async {
        precondition(Thread.current.isMainThread)
        // todo
    }
}
