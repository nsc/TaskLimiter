import os

public struct TaskLimiter : Sendable {
    public init(limitTo maximumConcurrentTasks: Int = 1) {
        protectedState = .init(initialState: .init(maximumConcurrentTasks: maximumConcurrentTasks))
    }

    public func callAsFunction<Return, Failure: Error>(
        isolation: isolated (any Actor)? = #isolation,
        _ task: () async throws(Failure) -> sending Return
    ) async throws(Failure) -> sending Return {

        await withCheckedContinuation(isolation: isolation) { continuation in
            protectedState.withLock { state in
                if state.currentlyRunningTasks >= state.maximumConcurrentTasks {
                    state.waitingTasks.append(continuation)
                } else {
                    state.currentlyRunningTasks += 1
                    continuation.resume()
                }
            }
        }

        defer { protectedState.withLock { $0.completeTask() } }

        return try await task()
    }


    let protectedState: OSAllocatedUnfairLock<State>
    struct State {
        let maximumConcurrentTasks: Int
        var currentlyRunningTasks: Int = 0
        var waitingTasks: [CheckedContinuation<Void, Never>] = []

        fileprivate mutating func completeTask() {
            currentlyRunningTasks -= 1

            if !waitingTasks.isEmpty {
                currentlyRunningTasks += 1
                waitingTasks.removeFirst().resume()
            }
        }
    }
}
