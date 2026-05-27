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
        let result1 = parseConfig("exec.inherit-env-vars = false")
        assertEquals(result1.errors, [])
        assertEquals(result1.config.execConfig.envVariables, [:])

        let result2 = parseConfig("exec.inherit-env-vars = true")
        assertEquals(result2.errors, [])
        assertEquals(result2.config.execConfig.envVariables, testEnv)
    }

    func testAddVars() {
        let result = parseConfig(
            """
            [exec.env-vars]
            FOO = 'BAR'
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(result.config.execConfig.envVariables, testEnv + ["FOO": "BAR"])
    }

    func testCyclicDep() {
        let errors = parseConfig(
            """
            [exec.env-vars]
            FOO = '${BAR}'
            BAR = '${FOO}'
            """,
        ).strErrors
        assertEquals(errors, [
            "[ERROR] exec.env-vars.BAR: Env variable 'FOO' isn't presented in AeroSpace.app env vars, or not available for interpolation (because it's mutated)",
            "[ERROR] exec.env-vars.FOO: Env variable 'BAR' isn't presented in AeroSpace.app env vars, or not available for interpolation (because it's mutated)",
        ])
    }

    func testForbidPwd() {
        let errors = parseConfig(
            """
            [exec.env-vars]
            PWD = ''
            """,
        ).strErrors
        assertEquals(errors, ["[ERROR] exec.env-vars.PWD: Changing 'PWD' is not allowed"])
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
