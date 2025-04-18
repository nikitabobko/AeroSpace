import AppKit
import Common
import UserNotifications

struct ShowNotificationCommand: Command {
    let args: ShowNotificationCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        // Task { @MainActor in
        //     let alert = NSAlert()
        //     alert.messageText = args.title.val
        //     alert.informativeText = args.body.val
        //     alert.alertStyle = .warning
        //     alert.addButton(withTitle: "OK")
        //     alert.addButton(withTitle: "Cancel")
        //     alert.runModal()
        // }

        CFUserNotificationDisplayNotice(
            0,
            kCFUserNotificationCautionAlertLevel,
            nil,
            nil,
            nil,
            args.title.val as CFString,
            args.body.val as CFString,
            "OK" as CFString
        )

        // UNUserNotificationCenter.current().requestAuthorization() { granted, error in
        //     if !granted { return }
        //     let content = UNMutableNotificationContent()
        //     content.title = args.title.val
        //     content.subtitle = args.body.val
        //
        //     let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0, repeats: false)
        //     let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        //     UNUserNotificationCenter.current().add(request)
        // }
        return true
    }
}
