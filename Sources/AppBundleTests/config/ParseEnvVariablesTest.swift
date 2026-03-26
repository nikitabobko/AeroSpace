@testable import AppBundle
import Common
import XCTest

@MainActor
final class ParseEnvVariablesTest: XCTestCase {
    func testInterpolation() {
        testSucInterpolation("echo ${foo}", ["foo": "bar"], expected: "echo bar")
        testSucInterpolation("echo $foo", expected: "echo $foo")
        testSucInterpolation("echo $$foo", expected: "echo $$foo")
        testSucInterpolation("echo $${foo}", ["foo": "bar"], expected: "echo $bar")
        testSucInterpolation("echo $", expected: "echo $")

        testFailInterpolation("echo ${foo")
        testFailInterpolation("echo ${foo{bar}")
        testFailInterpolation("echo ${foo$bar}")
        testFailInterpolation("echo ${foo}")
    }

    func testInherit() {
        let (config1, errors1) = parseConfig("exec.inherit-env-vars = false")
        assertEquals(errors1, [])
        assertEquals(config1.execConfig.envVariables, [:])

        let (config2, errors2) = parseConfig("exec.inherit-env-vars = true")
        assertEquals(errors2, [])
        assertEquals(config2.execConfig.envVariables, testEnv)
    }

    func testAddVars() {
        let (config, errors) = parseConfig(
            """
            [exec.env-vars]
            FOO = 'BAR'
            """,
        )
        assertEquals(errors, [])
        assertEquals(config.execConfig.envVariables, testEnv + ["FOO": "BAR"])
    }

    func testCyclicDep() {
        let (_, errors) = parseConfig(
            """
            [exec.env-vars]
            FOO = '${BAR}'
            BAR = '${FOO}'
            """,
        )
        assertEquals(errors, [
            "exec.env-vars.BAR: Env variable 'FOO' isn't presented in AeroSpace.app env vars, or not available for interpolation (because it's mutated)",
            "exec.env-vars.FOO: Env variable 'BAR' isn't presented in AeroSpace.app env vars, or not available for interpolation (because it's mutated)",
        ])
    }

    func testForbidPwd() {
        let (_, errors) = parseConfig(
            """
            [exec.env-vars]
            PWD = ''
            """,
        )
        assertEquals(errors, ["exec.env-vars.PWD: Changing 'PWD' is not allowed"])
    }
}

private func testSucInterpolation(_ str: String, _ vars: [String: String] = [:], expected: String) {
    switch str.interpolate(with: vars) {
        case .success(let actual): assertEquals(actual, expected)
        case .failure(let actual): assertEquals(actual, [])
    }
}

private func testFailInterpolation(_ str: String, _ vars: [String: String] = [:]) {
    switch str.interpolate(with: vars) {
        case .success(let actual): failExpectedActual(nil, actual)
        case .failure: break
    }
}
