import XCTest
@testable import AeroSpace_Debug

final class ConfigTest: XCTestCase {
    func testParseI3Config() throws {
        let toml = try! String(contentsOf: projectRoot.appending(component: "config-examples/i3-like-config-example.toml"))
        let _ = parseConfig(toml)
    }
}
