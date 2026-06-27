/// Bounded loop execution with pluggable stop conditions.

import Foundation

/// Result of a single loop iteration.
public enum LoopIterationResult: Sendable, Equatable {
    case continued
    case checkpoint(summary: String)
    case stopped(signal: StopSignal, summary: String)
    case failed(String)
}

/// Context maintained across loop iterations.
public struct LoopContext: Sendable, Equatable {
    public let taskRef: String
    public var iteration: Int
    public let startedAt: Date
    public var timeBudget: TimeInterval?
    public var maxIterations: Int?
    public var lastResult: LoopIterationResult?
    public var stopSignals: [StopSignal]

    public init(
        taskRef: String,
        iteration: Int = 0,
        startedAt: Date = Date(),
        timeBudget: TimeInterval? = nil,
        maxIterations: Int? = nil,
        lastResult: LoopIterationResult? = nil,
        stopSignals: [StopSignal] = []
    ) {
        self.taskRef = taskRef
        self.iteration = iteration
        self.startedAt = startedAt
        self.timeBudget = timeBudget
        self.maxIterations = maxIterations
        self.lastResult = lastResult
        self.stopSignals = stopSignals
    }

    public var elapsed: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }

    public var isWithinTimeBudget: Bool {
        guard let budget = timeBudget else { return true }
        return elapsed < budget
    }

    public var isWithinIterationLimit: Bool {
        guard let limit = maxIterations else { return true }
        return iteration < limit
    }
}

/// Protocol for stop conditions that inspect loop context.
public protocol StopCondition: Sendable {
    /// Human-readable name for traces.
    var name: String { get }

    /// Evaluate whether the loop should stop. Returns the signal if it should.
    func shouldStop(context: LoopContext) async -> StopSignal?
}

/// Stop after a maximum number of iterations.
public struct IterationLimit: StopCondition {
    public let name = "iteration-limit"
    public let limit: Int

    public init(_ limit: Int) {
        self.limit = limit
    }

    public func shouldStop(context: LoopContext) async -> StopSignal? {
        guard context.iteration >= limit else { return nil }
        return .iterationLimitReached
    }
}

/// Stop after a time budget is exhausted.
public struct TimeBudget: StopCondition {
    public let name = "time-budget"
    public let budget: TimeInterval

    public init(_ budget: TimeInterval) {
        self.budget = budget
    }

    public func shouldStop(context: LoopContext) async -> StopSignal? {
        guard context.elapsed >= budget else { return nil }
        return .timeBudgetExpired
    }
}

/// Stop when a signal is explicitly recorded in the loop context.
public struct SignalStop: StopCondition {
    public let name = "signal-stop"

    public init() {}

    public func shouldStop(context: LoopContext) async -> StopSignal? {
        context.stopSignals.first
    }
}

/// Stop after a threshold of consecutive failures.
public struct ErrorThreshold: StopCondition {
    public let name = "error-threshold"
    public let maxFailures: Int

    public init(_ maxFailures: Int) {
        self.maxFailures = maxFailures
    }

    public func shouldStop(context: LoopContext) async -> StopSignal? {
        guard case .failed = context.lastResult else { return nil }
        // The context does not track consecutive failures; this condition is
        // evaluated by the runner which maintains a local failure counter.
        return nil
    }
}

/// Runs a body in a bounded loop, checking stop conditions before each iteration.
public actor BoundedLoop {
    public let taskRef: String
    public let conditions: [StopCondition]

    public init(taskRef: String, conditions: [StopCondition]) {
        self.taskRef = taskRef
        self.conditions = conditions
    }

    /// Run the loop.
    /// - Parameters:
    ///   - context: Initial loop context.
    ///   - body: Closure returning the iteration result. Called once per iteration.
    /// - Returns: The final loop context.
    public func run(
        context: LoopContext,
        body: @Sendable (LoopContext) async -> LoopIterationResult
    ) async -> LoopContext {
        var ctx = context
        var consecutiveFailures = 0

        while true {
            // Evaluate stop conditions before the next iteration.
            for condition in conditions {
                if let signal = await condition.shouldStop(context: ctx) {
                    ctx.lastResult = .stopped(signal: signal, summary: "Stopped by \(condition.name)")
                    return ctx
                }
            }

            guard ctx.isWithinTimeBudget, ctx.isWithinIterationLimit else {
                if !ctx.isWithinTimeBudget {
                    ctx.lastResult = .stopped(signal: .timeBudgetExpired, summary: "Time budget exhausted")
                } else {
                    ctx.lastResult = .stopped(signal: .iterationLimitReached, summary: "Iteration limit reached")
                }
                return ctx
            }

            ctx.iteration += 1
            let result = await body(ctx)
            ctx.lastResult = result

            switch result {
            case .continued:
                consecutiveFailures = 0
            case .checkpoint:
                consecutiveFailures = 0
            case .stopped(let signal, _):
                ctx.stopSignals.append(signal)
                return ctx
            case .failed:
                consecutiveFailures += 1
                if let errorThreshold = conditions.first(where: { $0 is ErrorThreshold }) as? ErrorThreshold,
                   consecutiveFailures >= errorThreshold.maxFailures {
                    ctx.lastResult = .stopped(signal: .errorThreshold, summary: "Error threshold exceeded")
                    return ctx
                }
            }
        }
    }
}
