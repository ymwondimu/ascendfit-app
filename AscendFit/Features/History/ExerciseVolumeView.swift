import SwiftUI
import Charts

struct ExerciseVolumeView: View {
    let progress: ExerciseProgress
    @State private var selectedUnit: MassUnit?
    @State private var selectedDate: Date?

    var body: some View {
        let units = progress.volumeUnits
        if let fallback = units.first {
            let unit = selectedUnit.flatMap { units.contains($0) ? $0 : nil } ?? fallback
            let points = progress.volumePoints(unit: unit)
            Section("Recorded load volume") {
                Picker("Volume unit", selection: Binding(get: { unit }, set: { selectedUnit = $0; selectedDate = nil })) {
                    ForEach(units, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("exercise-volume-unit")
                if points.count >= 2 {
                    Chart(points) { point in
                        BarMark(x: .value("Workout", point.date),
                                y: .value("\(unit.rawValue) × reps", NSDecimalNumber(decimal: point.amount).doubleValue))
                            .foregroundStyle(AppTheme.accentContent)
                    }
                    .frame(height: 150)
                    .chartXSelection(value: $selectedDate)
                    .chartYAxis { AxisMarks { AxisValueLabel() } }
                    .accessibilityLabel("Recorded load volume by workout in \(unit.rawValue)")
                    .accessibilityValue(summary(points, unit: unit))
                    if let selectedDate,
                       let nearest = points.min(by: { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }) {
                        Text("\(nearest.date.formatted(date: .abbreviated, time: .omitted)): \(nearest.amount.formatted()) \(unit.rawValue) × reps")
                            .font(.caption).accessibilityAddTraits(.updatesFrequently)
                    }
                }
                Text(summary(points, unit: unit))
                    .font(.subheadline)
                    .accessibilityIdentifier("exercise-volume-summary")
                if points.count == 1 {
                    Text("One workout recorded in this unit. More workouts will add volume bars.")
                        .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                }
                Text("External load × logged reps, including weighted AMRAP. Bodyweight, assistance, timed and distance sets are excluded. Per-side results are counted as entered, without doubling. Units stay separate.")
                    .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                ForEach(points.reversed()) { point in
                    LabeledContent(point.date.formatted(date: .abbreviated, time: .omitted),
                                   value: "\(point.amount.formatted()) \(unit.rawValue) × reps")
                        .font(.caption)
                        .accessibilityElement(children: .combine)
                }
            }
            .listRowBackground(AppTheme.surfacePrimary)
        }
    }

    private func summary(_ points: [ExerciseVolumePoint], unit: MassUnit) -> String {
        guard let latest = points.last else { return "No recorded load volume." }
        let total = points.reduce(Decimal.zero) { $0 + $1.amount }
        return "\(points.count) workout\(points.count == 1 ? "" : "s") · total \(total.formatted()) \(unit.rawValue) × reps. Latest: \(latest.amount.formatted()) \(unit.rawValue) × reps on \(latest.date.formatted(date: .abbreviated, time: .omitted))."
    }
}
