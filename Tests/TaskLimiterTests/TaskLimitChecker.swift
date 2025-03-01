import Testing
import Synchronization


/// A helper type that asserts concurrency limits are not exceeded in unit tests.
internal final class TaskLimitChecker: Sendable {

    init(expectedMaximumConcurrency: Int) {
        self.protectedState = Mutex(State(taskLimit: expectedMaximumConcurrency))
    }

    var state: State { protectedState.withLock { $0 } }

    func expectLimitedConcurrency<Return, Failure: Error>(
        isolation: isolated (any Actor)? = #isolation,
        _ body: () async throws(Failure) -> sending Return
    ) async throws -> sending Return {

        protectedState.withLock { $0.enterLimitedConcurrency() }

        do {
            let result = try await body()
            protectedState.withLock { $0.exitLimitedConcurrency(withError: false) }
            return result
        } catch {
            protectedState.withLock { $0.exitLimitedConcurrency(withError: true) }
            throw error
        }
    }

    private let protectedState: Mutex<State>

    struct State {
        let taskLimit: Int
        var startedTaskCount = 0
        var successfulTaskCount = 0
        var failedTaskCount = 0

        var endedTaskCount: Int { successfulTaskCount + failedTaskCount }
        var currentTaskCount: Int { startedTaskCount - endedTaskCount }

        mutating func enterLimitedConcurrency() {
            startedTaskCount += 1
            #expect(
                currentTaskCount <= taskLimit,
                "maximum expected concurrency exceeded"
            )
        }

        mutating func exitLimitedConcurrency(withError: Bool) {
            #expect(startedTaskCount > endedTaskCount)
            if withError {
                failedTaskCount += 1
            } else {
                successfulTaskCount += 1
            }
        }
    }
}
