import SwiftUI

struct ImportedExerciseEditor: View {
    @Binding var exercise: ImportedExercise
    let mapped: ExerciseDefinition?
    let onMap: (ExerciseDefinition) -> Void
    @State private var isMatching = false
    @State private var localMapping: ExerciseDefinition?

    var body: some View {
        List {
            Section("Exercise") {
                Text(exercise.name).font(.headline)
                if let definition = localMapping ?? mapped { Text("Using: \(definition.name)").font(.subheadline) }
                Button("Match exercise library") { isMatching = true }
                Button("Keep as custom exercise") {
                    if let definition = try? ExerciseDefinition(name: exercise.name, equipment: exercise.equipment) {
                        localMapping = definition; onMap(definition)
                    }
                }
                .accessibilityIdentifier("import-keep-custom")
                TextField("Exercise notes", text: Binding(get: { exercise.notes ?? "" }, set: { exercise.notes = $0 }), axis: .vertical)
            }
            Section("Sets") {
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                    NavigationLink {
                        ImportedSetEditor(set: $exercise.sets[index], position: index + 1)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Set \(index + 1) · \(set.kind)")
                            if let planned = try? set.plannedSet() {
                                Text(planned.prescription.summaryText).font(.caption)
                            } else { Text("Needs correction").font(.caption).foregroundStyle(.orange) }
                            Text(set.restSeconds.map { "\($0) sec rest" } ?? "Rest not specified")
                                .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                        }
                    }
                    .accessibilityIdentifier("import-set-\(index)")
                }
            }
            if let group = exercise.group {
                Section("Grouping") {
                    Text("\(group.kind.capitalized) · position \(group.position + 1)")
                    Text("To change grouping or add/remove sets, edit the source JSON and review it again.").font(.caption)
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isMatching) {
            ImportExerciseMatcher { definition in localMapping = definition; onMap(definition) }
        }
    }
}

private struct ImportExerciseMatcher: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    let onSelect: (ExerciseDefinition) -> Void
    var body: some View {
        NavigationStack {
            List(ExerciseCatalog.exercises.filter { query.isEmpty || $0.searchableText.localizedCaseInsensitiveContains(query) }) { exercise in
                Button(exercise.name) { onSelect(exercise.definition); dismiss() }
            }
            .searchable(text: $query, prompt: "Search exercises")
            .navigationTitle("Match exercise")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

private struct ImportedSetEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var set: ImportedSet
    let position: Int
    @State private var kind: String
    @State private var role: String
    @State private var side: String
    @State private var minimum: String
    @State private var maximum: String
    @State private var load: String
    @State private var massUnit: String
    @State private var seconds: String
    @State private var distance: String
    @State private var distanceUnit: String
    @State private var rest: String
    @State private var effortKind: String
    @State private var effort: String
    @State private var message: String?

    init(set: Binding<ImportedSet>, position: Int) {
        _set = set; self.position = position
        let value = set.wrappedValue
        _kind = State(initialValue: value.kind); _role = State(initialValue: value.role); _side = State(initialValue: value.side)
        _minimum = State(initialValue: value.reps.map { String($0.min) } ?? "")
        _maximum = State(initialValue: value.reps.map { String($0.max) } ?? "")
        _load = State(initialValue: value.load.map { NSDecimalNumber(decimal: $0.amount).stringValue } ?? "")
        _massUnit = State(initialValue: value.load?.unit ?? "")
        _seconds = State(initialValue: value.durationSeconds.map(String.init) ?? "")
        _distance = State(initialValue: value.distance.map { NSDecimalNumber(decimal: $0.amount).stringValue } ?? "")
        _distanceUnit = State(initialValue: value.distance?.unit ?? "")
        _rest = State(initialValue: value.restSeconds.map(String.init) ?? "")
        _effortKind = State(initialValue: value.effort?.kind ?? "")
        _effort = State(initialValue: value.effort.map { NSDecimalNumber(decimal: $0.value).stringValue } ?? "")
    }

    var body: some View {
        Form {
            Section("Prescription") {
                picker("Type", selection: $kind, values: ["weighted", "bodyweight", "assistedBodyweight", "amrap", "timed", "distance"])
                picker("Role", selection: $role, values: ["working", "warmUp", "drop", "failure"])
                picker("Side", selection: $side, values: ExerciseSide.allCases.map(\.rawValue))
                if ["weighted", "bodyweight", "assistedBodyweight"].contains(kind) {
                    field("Minimum reps", text: $minimum)
                    field("Maximum reps (same for exact)", text: $maximum)
                }
                if ["weighted", "assistedBodyweight", "amrap", "timed"].contains(kind) {
                    field(kind == "assistedBodyweight" ? "Assistance" : "Weight", text: $load)
                    picker("Weight unit", selection: $massUnit, values: ["", "kg", "lb"])
                }
                if ["timed", "distance"].contains(kind) { field("Duration seconds", text: $seconds) }
                if kind == "distance" {
                    field("Distance", text: $distance)
                    picker("Distance unit", selection: $distanceUnit, values: ["", "m", "km", "mi"])
                }
                field("Rest seconds (blank if unspecified)", text: $rest)
                picker("Effort", selection: $effortKind, values: ["", "rpe", "rir"])
                if !effortKind.isEmpty { field("Effort value", text: $effort) }
                if set.tempo != nil { Text("Tempo from the source is preserved. Edit the JSON to change it.").font(.caption) }
            }
            if let message { Text(message).foregroundStyle(.red) }
        }
        .navigationTitle("Set \(position)")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save set") { save() } } }
    }

    private func picker(_ title: String, selection: Binding<String>, values: [String]) -> some View {
        Picker(title, selection: selection) { ForEach(values, id: \.self) { Text($0.isEmpty ? "Not specified" : $0).tag($0) } }
    }
    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading) { Text(title).font(.caption); TextField(title, text: text).keyboardType(.decimalPad) }
    }
    private func integer(_ text: String) throws -> Int? {
        if text.isEmpty { return nil }
        guard let value = Int(text) else { throw WorkoutImportError.invalid("Enter whole numbers for reps and seconds.") }
        return value
    }
    private func decimal(_ text: String) throws -> Decimal? {
        if text.isEmpty { return nil }
        guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else { throw WorkoutImportError.invalid("Enter valid numeric values.") }
        return value
    }
    private func save() {
        do {
            var updated = set
            updated.kind = kind; updated.role = role; updated.side = side
            updated.reps = nil; updated.load = nil; updated.durationSeconds = nil; updated.distance = nil
            if ["weighted", "bodyweight", "assistedBodyweight"].contains(kind), let min = try integer(minimum) {
                updated.reps = ImportedReps(min: min, max: try integer(maximum) ?? min)
            }
            if ["weighted", "assistedBodyweight", "amrap", "timed"].contains(kind), let amount = try decimal(load) {
                updated.load = ImportedLoad(amount: amount, unit: massUnit.isEmpty ? nil : massUnit)
            }
            if ["timed", "distance"].contains(kind) { updated.durationSeconds = try integer(seconds) }
            if kind == "distance", let amount = try decimal(distance) { updated.distance = ImportedDistance(amount: amount, unit: distanceUnit.isEmpty ? nil : distanceUnit) }
            updated.restSeconds = try integer(rest)
            if !effortKind.isEmpty, let value = try decimal(effort) { updated.effort = ImportedEffort(kind: effortKind, value: value) }
            else { updated.effort = nil }
            _ = try updated.plannedSet()
            set = updated; dismiss()
        } catch { message = error.localizedDescription }
    }
}
