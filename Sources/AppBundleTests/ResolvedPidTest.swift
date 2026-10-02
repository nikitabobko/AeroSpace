@testable import AppBundle
import AppKit
import Darwin
import XCTest

final class ResolvedPidTest: XCTestCase {
    func testAppsWithValidPidsResolveToTheirReportedPids() {
        var checked = 0
        for app in NSWorkspace.shared.runningApplications {
            if app.processIdentifier > 0 {
                assertEquals(app.resolvedProcessIdentifier, app.processIdentifier)
                checked += 1
            }
        }
        assertTrue(checked > 0)
    }

    func testAppsWithInvalidPidsResolveToLivePidWithMatchingExecutable() {
        // Covers the fallback for apps LaunchServices reports with an invalid
        // PID (e.g. Xcode 27 DeviceHub reported as -1). Vacuous when no such
        // app is running.
        for app in NSWorkspace.shared.runningApplications {
            if app.processIdentifier > 0 { continue }
            let resolved = app.resolvedProcessIdentifier
            if resolved <= 0 { continue } // Resolver gives up honestly
            assertEquals(kill(resolved, 0), 0) // Must be a live process
            if let execPath = app.executableURL?.path {
                var path = [CChar](repeating: 0, count: 4 * 1024)
                let len = path.withUnsafeMutableBufferPointer { buf -> Int32 in
                    guard let base = buf.baseAddress else { return -1 }
                    return unsafe proc_pidpath(resolved, base, UInt32(buf.count))
                }
                assertTrue(len > 0)
                let actualPath = String(decoding: path.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
                assertEquals(actualPath, execPath)
            }
        }
    }
}
