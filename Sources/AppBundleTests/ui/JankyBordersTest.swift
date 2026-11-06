@testable import AppBundle
import Common
import Testing

struct JankyBordersTest {
    @Test func testJankyBordersArgs() {
        let janky = JankyBorders.parse(["active_color=0xffff6b8c", "inactive_color=0xff8083a0", "background_color=0x301c1d2a", "width=4", "hidpi=on", "style=square"])
        assertEquals(janky, JankyBorders(activeColor: ArgbColor(0xFFFF_6B8C), inactiveColor: ArgbColor(0xFF80_83A0), width: 4))
        assertEquals(JankyBorders.parse(["active_color=gradient(top_left=0xffff0000,bottom_right=0xff0000ff)", "width=6.5"]), JankyBorders(width: 6.5))
        assertEquals(JankyBorders.parse([]), JankyBorders())
    }
}
