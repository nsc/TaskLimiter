import Testing
import Foundation
import os
@testable import TaskLimiter


@Test func testBasicFunction() async throws {
    let limit = TaskLimiter(limitTo: 2)
    let checker = TaskLimitChecker(expectedMaximumConcurrency: 2)

    let results = try await withThrowingTaskGroup(of: Void.self) { group in
        for _ in 0..<10 {
            group.addTask {
                try await limit {
                    try await checker.expectLimitedConcurrency {
                        try await Task.sleep(for: .milliseconds(10))
                    }
                }
            }
        }

        try await group.waitForAll()
        return checker.state
    }

    #expect(results.startedTaskCount == 10)
    #expect(results.successfulTaskCount == 10)
    #expect(results.failedTaskCount == 0)
}


@Test func testCancellationHandling() async throws {
    let limit = TaskLimiter(limitTo: 2)
    let checker = TaskLimitChecker(expectedMaximumConcurrency: 2)

    let results = await withThrowingTaskGroup(of: Void.self) { group in
        let gate = TaskGate()

        for _ in 0 ..< 10 {
            group.addTask {
                await gate.pass()
                try await limit {
                    try await checker.expectLimitedConcurrency {
                        try await Task.sleep(for: .milliseconds(10))
                    }
                }
            }
        }

        group.cancelAll()
        gate.open()
        try? await group.waitForAll()
        return checker.state
    }

    #expect(results.currentTaskCount == 0)
    #expect(results.startedTaskCount == 0)
    #expect(results.successfulTaskCount == 0)
    #expect(results.failedTaskCount == 0)
}
