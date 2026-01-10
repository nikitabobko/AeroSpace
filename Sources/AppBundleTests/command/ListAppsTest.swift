@testable import AppBundle
import Common
import XCTest

final class ListAppsTest: XCTestCase {
    func testParse() {
        assertNotNil(parseCommand("list-apps --macos-native-hidden").cmdOrNil)
        assertNotNil(parseCommand("list-apps --macos-native-hidden no").cmdOrNil)
        assertNotNil(parseCommand("list-apps --format %{app-bundle-id}").cmdOrNil)
        assertNotNil(parseCommand("list-apps --count").cmdOrNil)
        assertEquals(parseCommand("list-apps --format %{app-bundle-id} --count").errorOrNil, "ERROR: Conflicting options: --count, --format")
        assertEquals(parseCommand("list-apps --format '%{all}'").errorOrNil, "'%{all}' format option requires --json flag")
        assertNil(parseCommand("list-apps --format '%{all}' --json").errorOrNil)
        assertEquals(parseCommand("list-apps --format '%{all} %{app-name}'").errorOrNil, "'%{all}' format option must be used alone and cannot be combined with other variables")
        assertEquals(parseCommand("list-apps --format '%{app-bundle-id} %{all}'").errorOrNil, "'%{all}' format option must be used alone and cannot be combined with other variables")
        assertNil(parseCommand("list-apps --format ' %{all} ' --json").errorOrNil)
    }
}
