let defaultConfig = ConfigRoot(
    config: Config(
        afterStartupCommand: NoOpCommand.instance,
        usePaddingForNestedContainersWithTheSameOrientation: false,
        autoFlattenContainers: true,
        floatingWindowsOnTop: true
    ),
    modes: [
        mainModeId: Mode(
            name: nil,
            bindings: [
                HotkeyBinding(.option, .return, BashCommand(bashCommand: "/usr/bin/open /System/Applications/Utilities/Terminal.app")),

                HotkeyBinding(.option, .h, FocusCommand(direction: .left)),
                HotkeyBinding(.option, .j, FocusCommand(direction: .down)),
                HotkeyBinding(.option, .k, FocusCommand(direction: .up)),
                HotkeyBinding(.option, .l, FocusCommand(direction: .right)),
            ]
        )
    ]
)
