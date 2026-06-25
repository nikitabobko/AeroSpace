import Common

struct EchoCommand: Command {
    let args: EchoCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        var obj = [AeroObj]()
        if let window = target.windowOrNil {
            guard let a: WindowWithPrefetchedTitle = try? await .resolveWindow(window, for: args.args.val.flatMap { $0 }, .nonCancellable) else { return .fail(io.err(bugPrompt())) }
            obj.append(AeroObj.window(a))
        } else {
            obj.append(AeroObj.workspace(target.workspace))
        }
        for argWithInterVars in args.args.val {
            guard let strs = obj.format(argWithInterVars).getOrNil(onFailure: { errs in
                for err in errs {
                    switch err {
                        case .unknownInterpolationVariable: io.err(noWindowIsFocused)
                        case .notPossible, .nullParent,
                             .rightPaddingCannotBeExpanded, .windowParentIllegalRelation: io.err(err.description)
                    }
                }
            }) else { return .fail }
            for str in strs {
                switch args.isStderr {
                    case true: io.err(str)
                    case false: io.out(str)
                }
            }
        }
        return .succ
    }
}
