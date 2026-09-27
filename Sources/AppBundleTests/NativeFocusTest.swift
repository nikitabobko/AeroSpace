@testable import AppBundle
import Common
import XCTest

final class NativeFocusTest: XCTestCase {
    func testPreCancelledJobRunsNoActions() {
        let job = RunLoopJob(.cancellable)
        job.cancel()
        var actions: [String] = []

        assertCancellation {
            try performNativeFocus(
                job: job,
                setMain: { actions.append("setMain") },
                raise: { actions.append("raise") },
                activate: { actions.append("activate") },
            )
        }

        assertEquals(actions, [])
    }

    func testCancellationDuringSetMainSkipsRaiseAndActivate() {
        let job = RunLoopJob(.cancellable)
        var actions: [String] = []

        assertCancellation {
            try performNativeFocus(
                job: job,
                setMain: {
                    actions.append("setMain")
                    job.cancel()
                },
                raise: { actions.append("raise") },
                activate: { actions.append("activate") },
            )
        }

        assertEquals(actions, ["setMain"])
    }

    func testCancellationDuringRaiseSkipsActivate() {
        let job = RunLoopJob(.cancellable)
        var actions: [String] = []

        assertCancellation {
            try performNativeFocus(
                job: job,
                setMain: { actions.append("setMain") },
                raise: {
                    actions.append("raise")
                    job.cancel()
                },
                activate: { actions.append("activate") },
            )
        }

        assertEquals(actions, ["setMain", "raise"])
    }

    func testUncancelledJobRunsActionsOnceInOrder() throws {
        let job = RunLoopJob(.cancellable)
        var actions: [String] = []

        try performNativeFocus(
            job: job,
            setMain: { actions.append("setMain") },
            raise: { actions.append("raise") },
            activate: { actions.append("activate") },
        )

        assertEquals(actions, ["setMain", "raise", "activate"])
    }

    func testSupersededJobStopsAndNewJobCompletes() throws {
        let firstJob = RunLoopJob(.cancellable)
        let secondJob = RunLoopJob(.cancellable)
        var actions: [String] = []

        assertCancellation {
            try performNativeFocus(
                job: firstJob,
                setMain: {
                    actions.append("first.setMain")
                    firstJob.cancel()
                },
                raise: { actions.append("first.raise") },
                activate: { actions.append("first.activate") },
            )
        }

        try performNativeFocus(
            job: secondJob,
            setMain: { actions.append("second.setMain") },
            raise: { actions.append("second.raise") },
            activate: { actions.append("second.activate") },
        )

        assertEquals(actions, ["first.setMain", "second.setMain", "second.raise", "second.activate"])
    }

    func testNonCancellableJobRunsActionsAfterCancel() throws {
        let job = RunLoopJob(.nonCancellable)
        job.cancel()
        var actions: [String] = []

        try performNativeFocus(
            job: job,
            setMain: { actions.append("setMain") },
            raise: { actions.append("raise") },
            activate: { actions.append("activate") },
        )

        assertEquals(job.isCancelled, false)
        assertEquals(actions, ["setMain", "raise", "activate"])
    }

    private func assertCancellation(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () throws -> Void,
    ) {
        do {
            try body()
            failExpectedActual("CancellationError", "no error thrown", file: file, line: line)
        } catch is CancellationError {
            // expected
        } catch {
            failExpectedActual("CancellationError", error, file: file, line: line)
        }
    }
}
