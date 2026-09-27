import SwiftUI
import Charts

struct ExerciseHistoryListView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""

    var body: some View {
        let exercises = ExerciseProgress.all(in: model.workoutHistory).filter {
            query.isEmpty || $0.exercise.name.localizedCaseInsensitiveContains(query)
        }
        List {
            if exercises.isEmpty {
                ContentUnavailableView("No exercise results", systemImage: "figure.strengthtraining.traditional",
                    description: Text("Logged sets appear here after you finish a workout."))
            }
            ForEach(exercises) { progress in
                NavigationLink {
                    ExerciseProgressView(progress: progress)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(progress.exercise.name).font(.headline)
                        if let equipment = progress.exercise.equipment {
                            Text(equipment).font(.caption).foregroundStyle(AppTheme.contentSecondary)
                        }
                        Text("\(progress.performances.count) logged sets")
                            .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                    }
                }
                .listRowBackground(AppTheme.surfacePrimary)
            }
        }
        .searchable(text: $query, prompt: "Exercise")
        .navigationTitle("Exercise progress")
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
    }
}

private struct ExerciseProgressView: View {
    let progress: ExerciseProgress
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSeries: String?
    @State private var selectedDate: Date?

    private var series: [(key: String, label: String)] {
        var seen: Set<String> = []
        return progress.performances.compactMap { performance in
            guard let comparison = performance.comparison, seen.insert(comparison.key).inserted else { return nil }
            return (comparison.key, comparison.label)
        }.sorted { $0.label < $1.label }
    }

    private var samples: [ExercisePerformance] {
        let key = selectedSeries ?? series.first?.key
        let matching = progress.performances.filter { $0.comparison?.key == key && key != nil }
        return Dictionary(grouping: matching, by: \.sessionID).values.compactMap { sets in
            sets.max { $0.comparison!.value < $1.comparison!.value }
        }.sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            if !series.isEmpty {
                Section("Best exact performance") {
                    Picker("Compare", selection: Binding(
                        get: { selectedSeries ?? series[0].key },
                        set: { selectedSeries = $0; selectedDate = nil }
                    )) {
                        ForEach(series, id: \.key) { option in
                            Text(option.label).tag(option.key)
                        }
                    }
                    .pickerStyle(.menu)
                    if let best = samples.max(by: { $0.comparison!.value < $1.comparison!.value }),
                       let comparison = best.comparison {
                        Text("\(comparison.value.formatted()) \(comparison.unit)")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.accentContent)
                        Text("Best logged result for the selected reps, side, role, and unit.")
                            .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                    }
                    if samples.count >= 3 {
                        Chart(samples) { sample in
                            if let comparison = sample.comparison {
                                LineMark(x: .value("Date", sample.date), y: .value(comparison.unit, NSDecimalNumber(decimal: comparison.value).doubleValue))
                                    .foregroundStyle(AppTheme.accentContent)
                                PointMark(x: .value("Date", sample.date), y: .value(comparison.unit, NSDecimalNumber(decimal: comparison.value).doubleValue))
                                    .foregroundStyle(AppTheme.accentContent)
                            }
                        }
                        .chartXSelection(value: $selectedDate)
                        .chartYAxis { AxisMarks { AxisValueLabel() } }
                        .frame(height: 170)
                        .accessibilityLabel("Best exact result by workout")
                        .accessibilityValue(chartSummary)
                        if let selectedDate,
                           let nearest = samples.min(by: { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }) {
                            Text("\(nearest.date.formatted(date: .abbreviated, time: .omitted)): \(nearest.completed.result.summaryText)")
                                .font(.caption).accessibilityAddTraits(.updatesFrequently)
                        }
                        Text(chartSummary).font(.caption).foregroundStyle(AppTheme.contentSecondary)
                    } else {
                        Text("More history needed") .font(.headline)
                        Text("A chart appears after three workouts with comparable sets. Your exact results are below.")
                            .font(.subheadline).foregroundStyle(AppTheme.contentSecondary)
                    }
                }
                .listRowBackground(AppTheme.surfacePrimary)
            } else {
                Section {
                    Text("Exact results") .font(.headline)
                    Text("These set types are shown as logged. They are not ranked against different set types or units.")
                        .font(.subheadline).foregroundStyle(AppTheme.contentSecondary)
                }
                .listRowBackground(AppTheme.surfacePrimary)
            }

            ExerciseVolumeView(progress: progress)

            if !progress.records.isEmpty {
                Section("New bests") {
                    ForEach(progress.records) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(record.value.formatted()) \(record.unit)").font(.headline)
                            Text(record.label).font(.caption)
                            Text("\(record.performance.date.formatted(date: .abbreviated, time: .omitted)) · Previous best \(record.previousBest.formatted()) \(record.unit)")
                                .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .listRowBackground(AppTheme.surfacePrimary)
            }

            Section("Logged sets · newest first") {
                ForEach(progress.performances) { performance in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(performance.completed.result.summaryText).font(.headline)
                        Text("\(performance.plannedSet.role.rawValue) · \(performance.plannedSet.side.rawValue)")
                            .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                        Text("\(performance.date.formatted(date: .abbreviated, time: .omitted)) · \(performance.workoutTitle)")
                            .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                        if let effort = performance.completed.effort {
                            Text(effort.historyText).font(.caption)
                        }
                        if let notes = performance.completed.notes { Text(notes).font(.caption) }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .listRowBackground(AppTheme.surfacePrimary)
        }
        .onAppear {
            let available = Set(model.workoutHistory.map(\.id))
            if progress.performances.contains(where: { !available.contains($0.sessionID) }) { dismiss() }
        }
        .onChange(of: model.workoutHistory.map(\.id), initial: true) { _, ids in
            // This screen is a snapshot. Dismiss after any contributing workout
            // is deleted so its sets cannot remain visible across tab changes.
            let available = Set(ids)
            if progress.performances.contains(where: { !available.contains($0.sessionID) }) { dismiss() }
        }
        .navigationTitle(progress.exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
    }

    private var chartSummary: String {
        guard let first = samples.first, let latest = samples.last else { return "No comparable results." }
        return "\(samples.count) workouts. First: \(first.completed.result.summaryText) on \(first.date.formatted(date: .abbreviated, time: .omitted)). Latest: \(latest.completed.result.summaryText) on \(latest.date.formatted(date: .abbreviated, time: .omitted))."
    }
}
