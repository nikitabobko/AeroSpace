@testable import AppBundle
import Common
import Foundation
import HotKey
import Testing

@MainActor
@Suite(.serializedGlobally)
struct ConfigCommandTest {
    init() { setUpWorkspacesForTests() }

    @Test func testParse() {
        assertNil(parseCommand("config --major-keys").errorOrNil)
        assertNil(parseCommand("config --all-keys").errorOrNil)
        assertNil(parseCommand("config --config-path").errorOrNil)
        assertNil(parseCommand("config --get foo").errorOrNil)
        assertNil(parseCommand("config --get foo --keys").errorOrNil)
        assertNil(parseCommand("config --get foo --json").errorOrNil)
        assertNil(parseCommand("config --get foo --keys --json").errorOrNil)

        assertEquals(
            parseCommand("config").errorOrNil,
            "Mandatory flag is not specified (--get|--major-keys|--all-keys|--config-path)",
        )
        // --keys/--json alone still trigger the mandatory-flag check first because they don't
        // contribute to the mandatory-flag set.
        assertEquals(
            parseCommand("config --keys").errorOrNil,
            "Mandatory flag is not specified (--get|--major-keys|--all-keys|--config-path)",
        )
        assertEquals(
            parseCommand("config --json").errorOrNil,
            "Mandatory flag is not specified (--get|--major-keys|--all-keys|--config-path)",
        )
        assertEquals(parseCommand("config --major-keys --keys").errorOrNil, "--keys flag requires --get flag")
        assertEquals(parseCommand("config --major-keys --json").errorOrNil, "--json flag requires --get flag")

        // Two mandatory flags are mutually exclusive. The collection of conflicting flag names
        // comes from a Set so we can't rely on the order, only the message shape.
        let conflictErr = parseCommand("config --major-keys --all-keys").errorOrNil
        assertTrue(conflictErr?.hasPrefix("Conflicting flags are specified:") == true)
        assertTrue(conflictErr?.contains("--major-keys") == true)
        assertTrue(conflictErr?.contains("--all-keys") == true)
    }

    @Test func testConfigPath() async {
        let result = await parseCommand("config --config-path").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, [configUrl.absoluteURL.path])
    }

    @Test func testMajorKeys() async {
        config.modes = [
            "main": Mode(bindings: [:]),
            "service": Mode(bindings: [:]),
        ]
        let result = await parseCommand("config --major-keys").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        // The whole listing comes back as one stdout entry separated by newlines.
        // Dict iteration order isn't stable, so sort before asserting.
        let lines = (result.stdout.singleOrNil() ?? "").split(separator: "\n").map(String.init).sorted()
        assertEquals(lines, [".", "mode", "mode.main.binding", "mode.service.binding"])
    }

    @Test func testAllKeys() async {
        let command = parseCommand("focus left").cmdOrDie
        let binding = HotkeyBinding(.option, .h, command)
        config.modes = ["main": Mode(bindings: [binding.descriptionWithKeyCode: binding])]

        let result = await parseCommand("config --all-keys").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        // Single mode + single binding => dict iteration order doesn't affect the output.
        assertEquals(
            result.stdout,
            [".\nmode\nmode.main\nmode.main.binding\nmode.main.binding.alt-h"],
        )
    }

    @Test func testGetRoot_complexObject_fails() async {
        let result = await parseCommand("config --get .").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(
            result.stderr,
            ["Complicated objects can be printed only with --json flag. Alternatively, you can try to inspect keys of the object with --keys flag"],
        )
    }

    @Test func testGetRoot_keys() async {
        config.modes = ["main": Mode(bindings: [:])]
        let result = await parseCommand("config --get . --keys").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["mode"])
    }

    @Test func testGetRoot_json() async {
        config.modes = ["main": Mode(bindings: [:])]
        let expectedMap: ConfigMapValue = .map(["mode": .map(["main": .map(["binding": .map([:])])])])
        let expectedJson = JSONEncoder.aeroSpaceDefault.encodeToString(expectedMap)

        let result = await parseCommand("config --get . --json").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, [expectedJson])
    }

    @Test func testGetRoot_keysJson() async {
        config.modes = ["main": Mode(bindings: [:])]
        // --keys converts the map into an array of string-scalar keys, which is then JSON-encoded.
        let expected = JSONEncoder.aeroSpaceDefault.encodeToString(
            ConfigMapValue.array([.scalar(.string("mode"))]),
        )

        let result = await parseCommand("config --get . --keys --json").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, [expected])
    }

    @Test func testGetMode_keys_sortedOutput() async {
        config.modes = [
            "main": Mode(bindings: [:]),
            "service": Mode(bindings: [:]),
        ]
        let result = await parseCommand("config --get mode --keys").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        // Plain (non-json) array output is sorted before printing.
        assertEquals(result.stdout, ["main\nservice"])
    }

    @Test func testGetScalar() async {
        let command = parseCommand("focus left").cmdOrDie
        let binding = HotkeyBinding(.option, .h, command)
        config.modes = ["main": Mode(bindings: [binding.descriptionWithKeyCode: binding])]

        let result = await parseCommand("config --get mode.main.binding.alt-h").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, [command.shellOfCommandsDescription])
    }

    @Test func testGetScalar_keys_fails() async {
        let command = parseCommand("focus left").cmdOrDie
        let binding = HotkeyBinding(.option, .h, command)
        config.modes = ["main": Mode(bindings: [binding.descriptionWithKeyCode: binding])]

        let result = await parseCommand("config --get mode.main.binding.alt-h --keys").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        // The error message interpolates the enum directly, yielding the default Swift case repr.
        assertEquals(result.stderr, ["--keys flag cannot be applied to scalar object 'string(\"\(command.shellOfCommandsDescription)\")'"])
    }

    @Test func testGetScalar_dereference_fails() async {
        let command = parseCommand("focus left").cmdOrDie
        let binding = HotkeyBinding(.option, .h, command)
        config.modes = ["main": Mode(bindings: [binding.descriptionWithKeyCode: binding])]

        let result = await parseCommand("config --get mode.main.binding.alt-h.foo").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["Can't dereference scalar value '\(command.shellOfCommandsDescription)'"])
    }

    @Test func testGetMissingKey_fails() async {
        let result = await parseCommand("config --get nonExistent").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["No value at key token 'nonExistent'"])
    }

    @Test func testGetInvalidPath_emptyKey() async {
        let result = await parseCommand("config --get ''").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["Invalid empty key"])
    }

    @Test func testGetInvalidPath_doubleDot() async {
        let result = await parseCommand("config --get a..b").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["Invalid key 'a..b'"])
    }

    @Test func testGetInvalidPath_trailingDot() async {
        let result = await parseCommand("config --get a.").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["Invalid key 'a.'"])
    }

    // The naturally-built configMap (buildConfigMap) never produces arrays, so the array branches
    // of ConfigMapValue.find/dumpAllKeysRecursive are exercised directly here.
    @Test func testFindArrayIndex_success() {
        let arr: ConfigMapValue = .array([.scalar(.string("a")), .scalar(.string("b"))])
        switch arr.find(keyPath: ["1"].slice) {
            case .success(.scalar(.string(let s))): assertEquals(s, "b")
            default: Issue.record(Comment(rawValue: "expected .scalar(.string(\"b\"))"))
        }
    }

    @Test func testFindArrayIndex_outOfBounds() {
        let arr: ConfigMapValue = .array([.scalar(.string("a"))])
        assertFail(arr.find(keyPath: ["5"].slice), "Index out of bounds. Index: 5, Size: 1")
    }

    @Test func testFindArrayIndex_notInt() {
        let arr: ConfigMapValue = .array([.scalar(.string("a"))])
        assertFail(arr.find(keyPath: ["foo"].slice), "Can't convert key token 'foo' to Int")
    }

    @Test func testDumpAllKeys_array() {
        let value: ConfigMapValue = .array([.scalar(.string("a")), .map(["k": .scalar(.int(1))])])
        var result: [String] = []
        value.dumpAllKeysRecursive(path: ".", result: &result)
        assertEquals(result, [".", "0", "1", "1.k"])
    }
}
