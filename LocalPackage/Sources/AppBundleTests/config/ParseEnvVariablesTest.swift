import XCTest
import Nimble
@testable import AeroSpace_Debug
import Common

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
        XCTAssertEqual(errors1.descriptions, [])
        XCTAssertEqual(config1.execConfig.envVariables, [:])

        let (config2, errors2) = parseConfig("exec.inherit-env-vars = true")
        XCTAssertEqual(errors2.descriptions, [])
        XCTAssertEqual(config2.execConfig.envVariables, testEnv)
    }

    func testAddVars() {
        let (config, errors) = parseConfig(
            """
            [exec.env-vars]
            FOO = 'BAR'
            """
        )
        expect(errors.descriptions).to(equal([]))
        expect(config.execConfig.envVariables).to(equal(testEnv + ["FOO": "BAR"]))
    }

    func testCyclicDep() {
        let (_, errors) = parseConfig(
            """
            [exec.env-vars]
            FOO = '${BAR}'
            BAR = '${FOO}'
            """
        )
        expect(errors.descriptions).to(equal([
            "exec.env-vars.BAR: Env variable 'FOO' isn't presented in AeroSpace.app Env vars, or not available for interpolation (because it's mutated)",
            "exec.env-vars.FOO: Env variable 'BAR' isn't presented in AeroSpace.app Env vars, or not available for interpolation (because it's mutated)"
        ]))
    }
}

private func testSucInterpolation(_ str: String, _ vars: [String: String] = [:], expected: String) {
    let (result, errors) = str.interpolate(with: vars)
    XCTAssertEqual(result, expected)
    XCTAssertEqual(errors, [])
}

private func testFailInterpolation(_ str: String, _ vars: [String: String] = [:]) {
    let (_, errors) = str.interpolate(with: vars)
    XCTAssertNotEqual(errors, [])
}
