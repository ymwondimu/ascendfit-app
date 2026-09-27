import Foundation

protocol PlannedWorkoutStore: Sendable {
    func saveScheduledWorkout(_ plan: WorkoutPlan) async throws
    func loadScheduledWorkout() async throws -> WorkoutPlan?
}

protocol SessionEventStore: Sendable {
    func create(_ session: WorkoutSession) async throws
    func append(_ event: SessionEvent) async throws
    func load(sessionID: UUID) async throws -> WorkoutSession?
    func loadLatestUnfinished() async throws -> WorkoutSession?
    func loadCompletedSessions() async throws -> [WorkoutSession]
}

actor WorkoutSessionCoordinator {
    private var session: WorkoutSession
    private let store: any SessionEventStore
    private let wallClock: @Sendable () -> Date
    private var isHandlingCommand = false
    private var pendingCommands: [CheckedContinuation<Void, Never>] = []

    init(
        session: WorkoutSession,
        store: any SessionEventStore,
        wallClock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.session = session
        self.store = store
        self.wallClock = wallClock
    }

    static func create(
        session: WorkoutSession,
        store: any SessionEventStore
    ) async throws -> WorkoutSessionCoordinator {
        try await store.create(session)
        return WorkoutSessionCoordinator(session: session, store: store)
    }

    func currentSession() -> WorkoutSession {
        session
    }

    @discardableResult
    func handle(
        _ command: SessionCommand,
        at date: Date? = nil
    ) async throws -> WorkoutSession {
        // Actor isolation alone does not protect the candidate across the store await.
        // Keep validation, persistence, and publication in command arrival order.
        await acquireCommandTurn()
        defer { releaseCommandTurn() }
        var candidate = session
        // Stamp queued actions when processed. A wall-clock rollback must not lock
        // users out of recording work, including after restoring a saved session.
        // Explicit dates remain subject to the domain's strict ordering validation.
        let eventDate: Date
        if let date {
            eventDate = date
        } else {
            let now = wallClock()
            eventDate = max(now, candidate.events.last?.occurredAt ?? now)
        }
        let event = try candidate.handle(command, at: eventDate)
        try await store.append(event)
        session = candidate
        return session
    }

    private func acquireCommandTurn() async {
        if isHandlingCommand {
            await withCheckedContinuation { pendingCommands.append($0) }
        } else {
            isHandlingCommand = true
        }
    }

    private func releaseCommandTurn() {
        if pendingCommands.isEmpty {
            isHandlingCommand = false
        } else {
            pendingCommands.removeFirst().resume()
        }
    }
}
