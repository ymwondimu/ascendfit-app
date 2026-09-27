import Foundation

extension SetResult {
    /// Recorded external load × repetitions. Do not invent body mass, assistance
    /// volume, or multipliers for alternating/per-side sets.
    var recordedLoadVolume: Load? {
        switch self {
        case let .weighted(reps, load), let .amrap(reps, .some(load)):
            return try? Load(amount: Decimal(reps.value) * load.amount, unit: load.unit)
        default: return nil
        }
    }
}

struct ExerciseVolumePoint: Identifiable, Sendable {
    var id: UUID { sessionID }
    let sessionID: UUID
    let date: Date
    let amount: Decimal
    let unit: MassUnit
}

extension ExerciseProgress {
    func volumePoints(unit: MassUnit) -> [ExerciseVolumePoint] {
        Dictionary(grouping: performances, by: \.sessionID).values.compactMap { samples in
            let volumes = samples.compactMap { $0.completed.result.recordedLoadVolume }.filter { $0.unit == unit }
            guard let first = samples.first, !volumes.isEmpty else { return nil }
            return ExerciseVolumePoint(sessionID: first.sessionID, date: first.date,
                                       amount: volumes.reduce(0) { $0 + $1.amount }, unit: unit)
        }.sorted {
            $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date
        }
    }

    var volumeUnits: [MassUnit] {
        MassUnit.allCases.filter { !volumePoints(unit: $0).isEmpty }
    }
}

struct HistoryActivityDay: Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let workoutCount: Int
    let volumes: [MassUnit: Decimal]
    let isFuture: Bool
}

struct HistoryActivityWindow: Sendable {
    let days: [HistoryActivityDay]

    init(history: [WorkoutHistoryEntry], now: Date = Date(), calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let start = calendar.date(byAdding: .weekOfYear, value: -11, to: weekStart) ?? today
        let grouped = Dictionary(grouping: history) { calendar.startOfDay(for: $0.summary.endedAt) }
        days = (0..<84).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let entries = grouped[date, default: []]
            var volumes: [MassUnit: Decimal] = [:]
            for entry in entries {
                for set in entry.session.completedSets {
                    if let volume = set.result.recordedLoadVolume {
                        volumes[volume.unit, default: 0] += volume.amount
                    }
                }
            }
            return HistoryActivityDay(date: date, workoutCount: entries.count, volumes: volumes, isFuture: date > today)
        }
    }

    /// Nearest-rank quartiles of positive daily volume in the selected unit.
    /// Ties share intensity, and a lone day belongs to the lowest quartile.
    func intensity(for day: HistoryActivityDay, unit: MassUnit) -> Int {
        guard let amount = day.volumes[unit], amount > 0 else { return 0 }
        let values = days.filter { !$0.isFuture }.compactMap { $0.volumes[unit] }.filter { $0 > 0 }.sorted()
        guard !values.isEmpty else { return 0 }
        for quartile in 1...3 {
            let index = max(0, Int(ceil(Double(values.count) * Double(quartile) / 4)) - 1)
            if amount <= values[index] { return quartile }
        }
        return 4
    }
}
