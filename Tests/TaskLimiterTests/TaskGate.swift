import Testing
import Synchronization


/// A helper type that prevents Tasks from advancing past a point before another
/// Task opens the gate.

internal final class TaskGate: Sendable {

    enum GateState {
        case open
        case closed
    }

    init(_ gate: GateState = .closed) {
        protectedState = Mutex(State(gate: gate))
    }

    var isOpen: Bool {
        protectedState.withLock { $0.gate == .open }
    }

    func open() {
        let continuations = protectedState.withLock {
            $0.gate = .open
            return $0.waitingTasks
        }

        for continuation in continuations {
            continuation.resume()
        }
    }

    func close() {
        protectedState.withLock { $0.gate = .closed }
    }

    func pass() async {
        await withCheckedContinuation { continuation in
            protectedState.withLock { state in
                if state.gate == .open {
                    continuation.resume()
                } else {
                    state.waitingTasks.append(continuation)
                }
            }
        }
    }

    private let protectedState: Mutex<State>

    struct State {
        var gate: GateState
        var waitingTasks: [CheckedContinuation<Void, Never>] = []
    }
}
