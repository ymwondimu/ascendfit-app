import Combine
import Foundation
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published var todayPlan: WorkoutPlan?
    @Published var activeSession: WorkoutSession?
    @Published private(set) var workoutHistory: [WorkoutHistoryEntry] = []
    @Published private(set) var latestSummary: WorkoutSummary?
    @Published private(set) var errorMessage: String?

    @Published private(set) var isRestoring = true
    @Published private(set) var isStarting = false
    @Published private(set) var isFinishing = false

    @Published private(set) var isMutatingWorkoutData = false

    private var historyGeneration = 0
    private let preferenceStore: UserDefaults
    private let sessionStore: SQLiteSessionEventStore?
    private var sessionCoordinator: WorkoutSessionCoordinator?
    private let restNotifications = LocalRestNotificationScheduler()

    init(preferenceStore: UserDefaults = .standard) {
        self.preferenceStore = preferenceStore
        do {
            let supportDirectory = try Self.applicationSupportDirectory()
            sessionStore = try SQLiteSessionEventStore(
                url: supportDirectory.appendingPathComponent("ascend-fit.sqlite")
            )
        } catch {
            sessionStore = nil
            isRestoring = false
            errorMessage = "Local storage could not be opened. \(error.localizedDescription)"
        }

        if ProcessInfo.processInfo.arguments.contains("--ui-testing-completion-plan") {
            todayPlan = try? Self.uiTestingCompletionPlan()
        } else if ProcessInfo.processInfo.arguments.contains("--ui-testing-seed-plan") {
            todayPlan = try? Self.uiTestingPlan()
        }

        if let sessionStore {
            Task { [weak self] in
                if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
                   ProcessInfo.processInfo.arguments.contains("--ui-testing-previous-performance") {
                    try? await Self.seedPreviousPerformance(in: sessionStore)
                }
                if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
                   ProcessInfo.processInfo.arguments.contains("--ui-testing-interrupted-finish"),
                   (try? await sessionStore.loadLatestUnfinished()) == nil,
                   (try? await sessionStore.loadCompletedSessions().isEmpty) == true {
                    try? await Self.seedInterruptedFinish(in: sessionStore)
                }
                await self?.restoreLatestSession(from: sessionStore)
                await self?.refreshHistory()
            }
        }
    }

    func schedule(_ plan: WorkoutPlan) async -> Bool {
        guard !isRestoring, !isStarting, !isMutatingWorkoutData, activeSession == nil, let sessionStore else {
            errorMessage = "The workout could not be saved. Wait for recovery or finish the active workout first."
            return false
        }
        isMutatingWorkoutData = true
        defer { isMutatingWorkoutData = false }
        do {
            try await sessionStore.saveScheduledWorkout(plan)
            todayPlan = plan
            errorMessage = nil
            return true
        } catch {
            errorMessage = "The workout could not be saved locally. Please try again."
            return false
        }
    }

    func startTodayWorkout() async {
        guard !isRestoring, !isStarting, !isMutatingWorkoutData, activeSession == nil else { return }
        isStarting = true
        defer { isStarting = false }
        guard let todayPlan, let sessionStore else {
            errorMessage = "The workout could not be started because local storage is unavailable."
            return
        }

        do {
            let initialSession = WorkoutSession(plan: todayPlan)
            let coordinator = try await WorkoutSessionCoordinator.create(
                session: initialSession,
                store: sessionStore
            )
            let started = try await coordinator.handle(.start)
            sessionCoordinator = coordinator
            activeSession = started
            errorMessage = nil
        } catch {
            errorMessage = "The workout could not be started. \(error.localizedDescription)"
        }
    }

    @discardableResult
    func logCurrentSet(
        result override: SetResult? = nil,
        updateRemainingSets: Bool = false,
        effort: EffortTarget? = nil,
        notes: String? = nil
    ) async -> Bool {
        guard let context = currentSetContext, let coordinator = sessionCoordinator else { return false }

        do {
            let result = try override
                ?? activeSession?.resultOverride(for: context.set.id)
                ?? context.set.prescription.defaultResult()
            if updateRemainingSets {
                activeSession = try await coordinator.handle(
                    .adjustRemainingSets(exerciseID: context.exercise.id, result: result)
                )
            }
            activeSession = try await coordinator.handle(
                .completeSet(
                    plannedSetID: context.set.id,
                    result: result,
                    effort: effort,
                    notes: notes
                )
            )
            await synchronizeRestNotification()
            errorMessage = nil
            return true
        } catch {
            errorMessage = "The set was not saved. \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func editCompletedSet(_ id: UUID, result: SetResult) async -> Bool {
        guard let existing = activeSession?.completedSets.first(where: { $0.id == id }) else { return false }
        return await editCompletedSet(id, result: result, effort: existing.effort, notes: existing.notes)
    }

    @discardableResult
    func editCompletedSet(_ id: UUID, result: SetResult, effort: EffortTarget?, notes: String?) async -> Bool {
        guard let coordinator = sessionCoordinator else { return false }
        do {
            activeSession = try await coordinator.handle(.editSet(completedSetID: id, result: result, effort: effort, notes: notes))
            await synchronizeRestNotification()
            errorMessage = nil
            return true
        } catch {
            errorMessage = "The completed set could not be updated. \(error.localizedDescription)"
            return false
        }
    }

    func selectNextSet(_ id: UUID) async -> Bool {
        guard let coordinator = sessionCoordinator else { return false }
        do {
            activeSession = try await coordinator.handle(.selectNextSet(id))
            errorMessage = nil
            return true
        } catch {
            errorMessage = "The set could not be selected. \(error.localizedDescription)"
            return false
        }
    }

    func deleteSet(_ plannedSetID: UUID) async {
        await send(
            .skipSet(plannedSetID: plannedSetID),
            failureMessage: "The set could not be deleted."
        )
    }

    func addSetToCurrentExercise(result: SetResult? = nil) async {
        guard let context = currentSetContext else { return }
        let source = context.set
        let addedSet = PlannedSet(
            role: source.role,
            prescription: result.flatMap { source.prescription.updating(with: $0) }
                ?? source.prescription,
            side: source.side,
            effortTarget: source.effortTarget,
            tempo: source.tempo,
            restAfter: source.restAfter
        )
        await send(
            .addSet(exerciseID: context.exercise.id, set: addedSet),
            failureMessage: "A set could not be added."
        )
    }

    func undoLastSet() async {
        await send(.undoLastSet, failureMessage: "The last set could not be undone.")
    }

    func pauseWorkout() async {
        await send(.pause, failureMessage: "The workout could not be paused.")
    }

    func resumeWorkout() async {
        await send(.resume, failureMessage: "The workout could not be resumed.")
    }

    func skipRest() async {
        await send(.endRest, failureMessage: "Rest could not be ended.")
    }

    func adjustRest(by seconds: Int) async {
        await send(
            .adjustRest(bySeconds: seconds),
            failureMessage: "Rest time could not be adjusted."
        )
    }

    func setExerciseRest(exerciseID: UUID, seconds: Int) async -> Bool {
        guard let coordinator = sessionCoordinator else { return false }
        do {
            let duration = try RestDuration(seconds: seconds)
            activeSession = try await coordinator.handle(.setExerciseRest(exerciseID: exerciseID, duration: duration))
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Rest time could not be saved. \(error.localizedDescription)"
            return false
        }
    }

    func finishWorkout(notes: String? = nil) async {
        guard !isFinishing, activeSession?.status.isTerminal == false,
              let coordinator = sessionCoordinator else { return }
        isFinishing = true
        defer { isFinishing = false }

        do {
            let completed = try await coordinator.handle(.finish(notes: notes))
            activeSession = completed
            latestSummary = try completed.makeSummary()
            todayPlan = nil
            await restNotifications.cancel()
            await refreshHistory()
            errorMessage = nil
        } catch {
            errorMessage = "The workout could not be finished. \(error.localizedDescription)"
        }
    }

    func closeCompletedWorkout() {
        guard activeSession?.status.isTerminal == true else { return }
        activeSession = nil
        sessionCoordinator = nil
        Task { await restNotifications.cancel() }
    }

    func discardWorkout() async {
        guard let coordinator = sessionCoordinator else { return }

        do {
            _ = try await coordinator.handle(.discard)
            activeSession = nil
            sessionCoordinator = nil
            todayPlan = nil
            latestSummary = nil
            await restNotifications.cancel()
            errorMessage = nil
        } catch {
            errorMessage = "The workout could not be discarded. \(error.localizedDescription)"
        }
    }

    func refreshHistory() async {
        guard let sessionStore, !isMutatingWorkoutData else { return }
        let generation = historyGeneration
        do {
            let entries = try await sessionStore.loadCompletedSessions().map {
                try WorkoutHistoryEntry(session: $0)
            }
            guard generation == historyGeneration else { return }
            workoutHistory = entries
        } catch {
            errorMessage = "Workout history could not be loaded. \(error.localizedDescription)"
        }
    }

    func coachReadyText(for entry: WorkoutHistoryEntry) -> String {
        let history = workoutHistory.contains(where: { $0.id == entry.id }) ? workoutHistory : workoutHistory + [entry]
        return entry.coachReadyText(recordLines: ExerciseProgress.recordLines(for: entry.id, in: history))
    }

    var currentSetContext: CurrentSetContext? {
        guard let session = activeSession else { return nil }
        let visibleOrder = session.executionOrder.filter { !session.skippedSetIDs.contains($0.set.id) }
        guard let nextIndex = visibleOrder.firstIndex(where: { $0.set.id == session.nextPendingSetID }) else { return nil }
        let next = visibleOrder[nextIndex]
        let visibleExercises = session.plan.exercises.filter { exercise in
            visibleOrder.contains { $0.exercise.id == exercise.id }
        }
        let exerciseSets = visibleOrder.filter { $0.exercise.id == next.exercise.id }.map(\.set)
        return CurrentSetContext(
            exercise: next.exercise,
            set: next.set,
            position: nextIndex + 1,
            total: visibleOrder.count,
            exercisePosition: (visibleExercises.firstIndex { $0.id == next.exercise.id } ?? 0) + 1,
            exerciseTotal: visibleExercises.count,
            setPosition: (exerciseSets.firstIndex { $0.id == next.set.id } ?? 0) + 1,
            setTotal: exerciseSets.count
        )
    }

    func replaceCurrentExercise(with replacement: ExerciseDefinition) async -> Bool {
        guard let context = currentSetContext, let coordinator = sessionCoordinator else { return false }
        do {
            activeSession = try await coordinator.handle(.replaceExercise(
                plannedExerciseID: context.exercise.id, replacement: replacement
            ))
            await synchronizeRestNotification()
            errorMessage = nil
            return true
        } catch {
            errorMessage = "The exercise could not be replaced. \(error.localizedDescription)"
            return false
        }
    }

    func deleteWorkout(sessionID: UUID) async -> Bool {
        guard !isRestoring, !isStarting, !isFinishing, !isMutatingWorkoutData, let sessionStore else { return false }
        isMutatingWorkoutData = true
        historyGeneration += 1
        defer { isMutatingWorkoutData = false }
        do {
            try await sessionStore.deleteCompletedSession(sessionID: sessionID)
            workoutHistory.removeAll { $0.id == sessionID }
            if activeSession?.id == sessionID {
                activeSession = nil
                sessionCoordinator = nil
                latestSummary = nil
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = "The workout could not be deleted. \(error.localizedDescription)"
            return false
        }
    }

    func deleteAllWorkoutData() async -> Bool {
        guard !isRestoring, !isStarting, !isFinishing, !isMutatingWorkoutData,
              activeSession?.status.isTerminal != false, let sessionStore else {
            errorMessage = "Finish or discard the active workout before deleting workout data."
            return false
        }
        isMutatingWorkoutData = true
        historyGeneration += 1
        defer { isMutatingWorkoutData = false }
        do {
            // Clear pending import text too. Accepted sources live inside plan JSON
            // and are deleted by the existing SQLite transaction.
            try AppSharedWorkoutInbox.open().deleteAll()
            try WorkoutImportStore().deleteAll()
            try await sessionStore.deleteAllWorkoutData()
            todayPlan = nil
            activeSession = nil
            sessionCoordinator = nil
            latestSummary = nil
            workoutHistory = []
            await restNotifications.cancel()
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Workout data could not be fully deleted. Some pending import data may already have been removed; try again. \(error.localizedDescription)"
            return false
        }
    }

    func updateRestNotificationPreference(enabled: Bool) async {
        preferenceStore.set(enabled, forKey: "preferences.restNotificationsEnabled")
        await synchronizeRestNotification()
    }

    func previousPerformance(for context: CurrentSetContext) -> PreviousSetPerformance? {
        guard let activeSession else { return nil }
        return PreviousSetPerformance.find(
            exercise: activeSession.exerciseReplacements[context.exercise.id] ?? context.exercise.exercise,
            set: context.set,
            exerciseSets: (context.exercise.sets + activeSession.addedSets[context.exercise.id, default: []]).filter {
                activeSession.exerciseDefinition(for: $0.id)?.id
                    == (activeSession.exerciseReplacements[context.exercise.id] ?? context.exercise.exercise).id
            },
            history: workoutHistory.filter { $0.id != activeSession.id }
        )
    }

    private func restoreLatestSession(from store: SQLiteSessionEventStore) async {
        defer { isRestoring = false }
        do {
            guard let storedSession = try await store.loadLatestUnfinished() else {
                if let savedPlan = try await store.loadScheduledWorkout() { todayPlan = savedPlan }
                await synchronizeRestNotification(allowPermissionRequest: false)
                return
            }
            let coordinator = WorkoutSessionCoordinator(session: storedSession, store: store)
            let session: WorkoutSession
            if case let .resting(deadline) = storedSession.status, deadline <= Date() {
                session = try await coordinator.handle(.endRest)
            } else {
                session = storedSession
            }
            sessionCoordinator = coordinator
            activeSession = session
            todayPlan = session.plan
            await synchronizeRestNotification(allowPermissionRequest: false)
        } catch {
            errorMessage = "The previous workout could not be restored. \(error.localizedDescription)"
        }
    }

    /// Reconcile external permission changes without asking for permission on arrival.
    func reconcileRestNotificationOnActivation() async {
        guard !isRestoring else { return }
        await synchronizeRestNotification(allowPermissionRequest: false)
    }

    private func synchronizeRestNotification(allowPermissionRequest: Bool = true) async {
        let enabled = preferenceStore.object(forKey: "preferences.restNotificationsEnabled") as? Bool ?? true
        guard enabled, let deadline = activeSession?.status.restDeadline, deadline > Date() else {
            await restNotifications.cancel()
            return
        }

        let nextSet = currentSetContext.map {
            "\(activeSession?.exerciseDefinition(for: $0.set.id)?.name ?? $0.exercise.exercise.name), set \($0.setPosition) of \($0.setTotal)"
        } ?? "Your next set"
        await restNotifications.schedule(deadline: deadline, nextSet: nextSet, allowPermissionRequest: allowPermissionRequest)
    }

    private func send(_ command: SessionCommand, failureMessage: String) async {
        guard let coordinator = sessionCoordinator else { return }
        do {
            activeSession = try await coordinator.handle(command)
            await synchronizeRestNotification()
            errorMessage = nil
        } catch {
            errorMessage = "\(failureMessage) \(error.localizedDescription)"
        }
    }

    private static func applicationSupportDirectory() throws -> URL {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let testID = ProcessInfo.processInfo.environment["ASCEND_FIT_UI_TEST_STORE_ID"]
                .flatMap(UUID.init(uuidString:)) ?? UUID()
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("AscendFitUITests-\(testID.uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            return directory
        }

        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("AscendFit", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private static func seedInterruptedFinish(in store: SQLiteSessionEventStore) async throws {
        let plan = try uiTestingPlan()
        let date = Date().addingTimeInterval(-60)
        let coordinator = try await WorkoutSessionCoordinator.create(
            session: WorkoutSession(plan: plan), store: store
        )
        try await coordinator.handle(.start, at: date)
        try await coordinator.handle(.completeSet(
            plannedSetID: plan.exercises[0].sets[0].id,
            result: .weighted(reps: CompletedReps(8), load: Load(amount: 100, unit: .pounds)),
            effort: nil, notes: nil
        ), at: date.addingTimeInterval(10))
        try await coordinator.handle(.prepareToFinish, at: date.addingTimeInterval(20))
    }

    private static func seedPreviousPerformance(in store: SQLiteSessionEventStore) async throws {
        let plan = try uiTestingPlan()
        let date = Date().addingTimeInterval(-86_400)
        let coordinator = try await WorkoutSessionCoordinator.create(
            session: WorkoutSession(plan: plan), store: store
        )
        try await coordinator.handle(.start, at: date)
        try await coordinator.handle(.completeSet(
            plannedSetID: plan.exercises[0].sets[0].id,
            result: .weighted(reps: CompletedReps(7), load: Load(amount: 95, unit: .pounds)),
            effort: nil, notes: nil
        ), at: date)
        try await coordinator.handle(.prepareToFinish, at: date)
        try await coordinator.handle(.finish(notes: nil), at: date)
    }

    private static func uiTestingPlan() throws -> WorkoutPlan {
        let target = try RepTarget(exact: 8)
        let load = try Load(amount: 100, unit: .pounds)
        let rest = try RestDuration(seconds: 90)
        let sets = (0 ..< 3).map { _ in
            PlannedSet(
                prescription: .weighted(reps: target, load: load),
                restAfter: rest
            )
        }
        let squat = try PlannedExercise(
            exercise: ExerciseDefinition(
                name: "Back Squat",
                description: "A barbell squat performed with the bar supported across the upper back.",
                equipment: "Barbell",
                primaryMuscles: ["Quadriceps", "Glutes"]
            ),
            sets: sets
        )
        let benchSets = (0 ..< 2).map { _ in
            PlannedSet(
                prescription: .weighted(reps: target, load: load),
                restAfter: rest
            )
        }
        let bench = try PlannedExercise(
            exercise: ExerciseDefinition(name: "Bench Press"),
            sets: benchSets
        )
        return try WorkoutPlan(title: "Lower A", exercises: [squat, bench])
    }

    private static func uiTestingCompletionPlan() throws -> WorkoutPlan {
        let exercise = try PlannedExercise(
            exercise: ExerciseDefinition(name: "Bench Press"),
            sets: [
                PlannedSet(
                    prescription: .weighted(
                        reps: RepTarget(exact: 8),
                        load: Load(amount: 100, unit: .pounds)
                    ),
                    restAfter: RestDuration(seconds: 0)
                )
            ]
        )
        return try WorkoutPlan(title: "Push Session", exercises: [exercise])
    }
}

private protocol RestNotificationScheduling: Sendable {
    func schedule(deadline: Date, nextSet: String, allowPermissionRequest: Bool) async
    func cancel() async
}

private actor LocalRestNotificationScheduler: RestNotificationScheduling {
    private let center = UNUserNotificationCenter.current()
    private let requestPrefix = "active-workout-rest-complete"
    private var generation = 0

    func schedule(deadline: Date, nextSet: String, allowPermissionRequest: Bool) async {
        guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return }
        generation += 1
        let token = generation
        let pending = await pendingRestNotificationIdentifiers()
        guard token == generation else { return }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        let statusCode: Int = await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus.rawValue)
            }
        }
        guard token == generation else { return }
        let isAuthorized: Bool
        switch RestNotificationPermissionPolicy.action(
            status: UNAuthorizationStatus(rawValue: statusCode) ?? .denied,
            allowPermissionRequest: allowPermissionRequest
        ) {
        case .request:
            isAuthorized = await withCheckedContinuation { continuation in
                center.requestAuthorization(options: [.alert]) { granted, error in
                    continuation.resume(returning: granted && error == nil)
                }
            }
        case .schedule:
            isAuthorized = true
        case .cancel:
            isAuthorized = false
        }
        guard isAuthorized, token == generation else { return }

        let interval = deadline.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "\(nextSet) is ready."
        content.sound = nil
        let requestID = "\(requestPrefix)-\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: requestID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, interval),
                repeats: false
            )
        )
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            center.add(request) { _ in
                continuation.resume()
            }
        }
        if token != generation {
            center.removePendingNotificationRequests(withIdentifiers: [requestID])
        }
    }

    func cancel() async {
        generation += 1
        let token = generation
        let pending = await pendingRestNotificationIdentifiers()
        guard token == generation else { return }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        let delivered = await deliveredRestNotificationIdentifiers()
        guard token == generation else { return }
        center.removeDeliveredNotifications(withIdentifiers: delivered)
    }

    private func pendingRestNotificationIdentifiers() async -> [String] {
        let prefix = requestPrefix
        return await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier).filter { $0.hasPrefix(prefix) })
            }
        }
    }

    private func deliveredRestNotificationIdentifiers() async -> [String] {
        let prefix = requestPrefix
        return await withCheckedContinuation { continuation in
            center.getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications.map(\.request.identifier).filter { $0.hasPrefix(prefix) })
            }
        }
    }
}

private extension WorkoutSessionStatus {
    var restDeadline: Date? {
        switch self {
        case let .resting(deadline):
            deadline
        default:
            nil
        }
    }
}

struct CurrentSetContext {
    let exercise: PlannedExercise
    let set: PlannedSet
    let position: Int
    let total: Int
    let exercisePosition: Int
    let exerciseTotal: Int
    let setPosition: Int
    let setTotal: Int
}

private extension SetPrescription {
    func defaultResult() throws -> SetResult {
        switch self {
        case let .weighted(reps, load):
            .weighted(reps: try reps.defaultCompletedReps(), load: load)
        case let .bodyweight(reps):
            .bodyweight(reps: try reps.defaultCompletedReps())
        case let .assistedBodyweight(reps, assistance):
            .assistedBodyweight(reps: try reps.defaultCompletedReps(), assistance: assistance)
        case let .amrap(load):
            .amrap(reps: try CompletedReps(1), load: load)
        case let .timed(duration, load):
            .timed(duration: duration, load: load)
        case let .distance(distance, duration):
            .distance(distance: distance, duration: duration)
        }
    }
}

private extension SetPrescription {
    func updating(with result: SetResult) -> SetPrescription? {
        switch (self, result) {
        case let (.weighted, .weighted(reps, load)):
            guard let target = try? RepTarget(exact: reps.value) else { return nil }
            return .weighted(reps: target, load: load)
        case let (.bodyweight, .bodyweight(reps)):
            guard let target = try? RepTarget(exact: reps.value) else { return nil }
            return .bodyweight(reps: target)
        case let (.assistedBodyweight, .assistedBodyweight(reps, assistance)):
            guard let target = try? RepTarget(exact: reps.value) else { return nil }
            return .assistedBodyweight(reps: target, assistance: assistance)
        case let (.amrap, .amrap(_, load)):
            return .amrap(load: load)
        case let (.timed, .timed(duration, load)):
            return .timed(duration: duration, load: load)
        case let (.distance, .distance(distance, duration)):
            return .distance(distance: distance, durationTarget: duration)
        default:
            return nil
        }
    }
}

private extension RepTarget {
    func defaultCompletedReps() throws -> CompletedReps {
        switch self {
        case let .exact(value):
            try CompletedReps(value)
        case let .range(lower, _):
            try CompletedReps(lower)
        }
    }
}
