import Testing
import Foundation
import os
@testable import TaskLimiter


@Test func testBasicFunction() async throws {
    let limit = TaskLimiter(limitTo: 2)

    let count = OSAllocatedUnfairLock(initialState: 0)
    try await withThrowingTaskGroup(of: Void.self) { group in
        for _ in 0..<10 {
            group.addTask {
                try await limit {
                    count.withLock { $0 += 1; #expect($0 <= 2) }
                    defer { count.withLock { $0 -= 1 } }

                    try await Task.sleep(for: .milliseconds(10))
                }
            }
        }

        try await group.waitForAll()
    }
}
