import AppKit

// actor AppActor {
//     // Potential alternative implementation https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md
//     nonisolated let pid: Int32
//     nonisolated let bundleId: String?
//     nonisolated let nsApp: NSRunningApplication
//     let axApp: AXUIElement
//     let axMap: [CGWindowID: AXUIElement] = [:]
//     let thread: Thread
//
//     init(_ nsApp: NSRunningApplication) {
//         // self.ax = ax
//         self.pid = nsApp.processIdentifier
//         self.bundleId = nsApp.bundleIdentifier
//         self.nsApp = nsApp
//     }
// }

// public struct NonSendable {
//     func foo() {}
// }
//
// actor Foo {
//     let foo: NonSendable
//
//     init(foo: NonSendable) {
//         self.foo = foo
//     }
// }
//
// func foo() {
//     let bar = NonSendable()
//     let foo = Foo(foo: bar)
//     bar.foo()
// }
