let defaultConfig = ConfigRoot(
    config: Config(
        afterStartupCommand: NoOpCommand.instance,
        usePaddingForNestedContainersWithTheSameOrientation: false,
        autoFlattenContainers: true,
        floatingWindowsOnTop: true
    ),
    modes: [
        Mode(
            id: "main",
            name: nil,
            bindings: [
                HotkeyBinding(.option, .h, FocusCommand(direction: .left)),
                HotkeyBinding(.option, .j, FocusCommand(direction: .down)),
                HotkeyBinding(.option, .k, FocusCommand(direction: .up)),
                HotkeyBinding(.option, .l, FocusCommand(direction: .right)),
            ]
        )
    ]
)
