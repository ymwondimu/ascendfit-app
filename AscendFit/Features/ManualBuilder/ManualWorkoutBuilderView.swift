import SwiftUI

struct ManualWorkoutBuilderView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var workoutTitle = "Today's Workout"
    @State private var exercises: [ManualExerciseDraft] = []
    @State private var isShowingCatalog = false
    @State private var isGrouping = false
    @State private var isShowingProfileEditor = false
    @State private var validationMessage: String?
    @State private var isSaving = false

    @AppStorage("trainingProfile.massUnit") private var unit = MassUnit.pounds
    @AppStorage("trainingProfile.sex") private var profileSex = TrainingSex.preferNotToSay.rawValue
    @AppStorage("trainingProfile.heightCentimeters") private var profileHeightCentimeters = 0.0
    @AppStorage("trainingProfile.bodyWeightKilograms") private var profileBodyWeightKilograms = 0.0
    @AppStorage("trainingProfile.experience") private var profileExperience = TrainingExperience.beginner.rawValue

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WORKOUT NAME")
                        .font(.caption2.weight(.medium))
                        .tracking(1.1)
                        .foregroundStyle(AppTheme.contentTertiary)

                    TextField("Workout title", text: $workoutTitle)
                        .font(.system(size: 22, weight: .semibold))
                        .textInputAutocapitalization(.words)
                        .foregroundStyle(AppTheme.contentPrimary)
                }
                .padding(.vertical, 8)

            }
            .listRowBackground(AppTheme.surfacePrimary)

            Section {
                Button {
                    isShowingProfileEditor = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(AppTheme.accentContent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(trainingProfile == nil ? "Set training profile" : "Starting weights personalized")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.contentPrimary)
                            Text(profileSummary)
                                .font(.caption)
                                .foregroundStyle(AppTheme.contentSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.contentTertiary)
                    }
                    .frame(minHeight: 48)
                }
                .buttonStyle(.plain)
            } footer: {
                Text("Estimated starting weights are conservative and editable. Use a load you can control with good technique.")
                    .foregroundStyle(AppTheme.contentTertiary)
            }
            .listRowBackground(AppTheme.surfacePrimary)

            if exercises.isEmpty {
                Section {
                    Button {
                        isShowingCatalog = true
                    } label: {
                        Label("Add your first exercise", systemImage: "plus.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.accentContent)
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .accessibilityIdentifier("add-first-exercise")
                } footer: {
                    Text("Choose from the exercise library. Sets, reps, and rest are filled in for you.")
                        .foregroundStyle(AppTheme.contentTertiary)
                }
                .listRowBackground(AppTheme.surfacePrimary)
            }

            if !exercises.isEmpty {
                Section {
                    ForEach($exercises) { $exercise in
                        NavigationLink {
                            ManualExerciseDetailView(exercise: $exercise, unit: unit)
                        } label: {
                            ManualExerciseSummaryRow(exercise: exercise, unit: unit)
                        }
                        .accessibilityIdentifier("builder-exercise-\(exercise.catalog.id)")
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                removeExercise(exercise.id)
                            }
                        }
                    }
                    .onMove(perform: moveExercises)
                } header: {
                    Text("Exercises")
                        .font(.caption.weight(.medium))
                        .tracking(1.1)
                        .foregroundStyle(AppTheme.contentTertiary)
                } footer: {
                    Text("Tap an exercise to edit its sets, weight, and rest. Swipe left to remove it.")
                        .foregroundStyle(AppTheme.contentTertiary)
                }
                .listRowBackground(AppTheme.surfacePrimary)
            }

            if !exercises.isEmpty {
                Section {
                    Button {
                        isShowingCatalog = true
                    } label: {
                        Label("Add another exercise", systemImage: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.accentContent)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .accessibilityIdentifier("add-another-exercise")
                    if exercises.count > 1 {
                        Button("Supersets & circuits", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
                            isGrouping = true
                        }.frame(minHeight: 44)
                    }
                }
                .listRowBackground(AppTheme.surfacePrimary)
            }

            if let validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                .listRowBackground(AppTheme.surfacePrimary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle("Build workout")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppTheme.accentContent)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.disabled(isSaving)
            }
            if !exercises.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !exercises.isEmpty {
                Button("Save workout") { Task { await save() } }
                    .disabled(isSaving || model.isRestoring)
                    .buttonStyle(PrimaryActionButtonStyle())
                    .padding(.horizontal, AppTheme.Spacing.screenInset)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(.ultraThinMaterial)
            }
        }
        .interactiveDismissDisabled(isSaving)
        .sheet(isPresented: $isShowingCatalog) {
            ExerciseCatalogPicker(selectedIDs: Set(exercises.map(\.catalog.id))) { exercise in
                guard !exercises.contains(where: { $0.catalog.id == exercise.id }) else { return }
                exercises.append(
                    ManualExerciseDraft(
                        catalog: exercise,
                        initialLoad: suggestedLoad(for: exercise) ?? 0
                    )
                )
                validationMessage = nil
            }
        }
        .sheet(isPresented: $isGrouping) {
            ManualGroupingEditor(exercises: $exercises)
        }
        .sheet(isPresented: $isShowingProfileEditor) {
            TrainingProfileEditor(unit: unit, profile: trainingProfile) { profile in
                save(profile)
            }
        }
    }

    private var trainingProfile: TrainingProfile? {
        guard profileHeightCentimeters > 0, profileBodyWeightKilograms > 0,
              let sex = TrainingSex(rawValue: profileSex),
              let experience = TrainingExperience(rawValue: profileExperience) else {
            return nil
        }
        return TrainingProfile(
            sex: sex,
            heightCentimeters: profileHeightCentimeters,
            bodyWeightKilograms: profileBodyWeightKilograms,
            experience: experience
        )
    }

    private var profileSummary: String {
        guard let trainingProfile else {
            return "Add height, body weight, and experience once"
        }
        let bodyWeight = unit == .pounds
            ? trainingProfile.bodyWeightKilograms * 2.204_622_621_8
            : trainingProfile.bodyWeightKilograms
        return "\(trainingProfile.experience.rawValue) · \(bodyWeight.formatted(.number.precision(.fractionLength(0)))) \(unit.rawValue)"
    }

    private func suggestedLoad(for exercise: CatalogExercise) -> Double? {
        guard let trainingProfile else { return nil }
        return StartingLoadSuggestion.amount(for: exercise, profile: trainingProfile, unit: unit)
    }

    private func save(_ profile: TrainingProfile) {
        profileSex = profile.sex.rawValue
        profileHeightCentimeters = profile.heightCentimeters
        profileBodyWeightKilograms = profile.bodyWeightKilograms
        profileExperience = profile.experience.rawValue

        for exerciseIndex in exercises.indices {
            guard let suggestion = StartingLoadSuggestion.amount(
                for: exercises[exerciseIndex].catalog,
                profile: profile,
                unit: unit
            ) else { continue }
            for setIndex in exercises[exerciseIndex].sets.indices
            where exercises[exerciseIndex].sets[setIndex].load == 0 {
                exercises[exerciseIndex].sets[setIndex].load = suggestion
            }
        }
    }

    private func moveExercises(from offsets: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: offsets, toOffset: destination)
    }

    private func removeExercise(_ id: UUID) {
        let groupID = exercises.first(where: { $0.id == id })?.groupID
        exercises.removeAll { $0.id == id }
        if let groupID, exercises.filter({ $0.groupID == groupID }).count == 1,
           let index = exercises.firstIndex(where: { $0.groupID == groupID }) {
            exercises[index].groupID = nil
        }
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let plannedExercises = try exercises.map { draft in
                let rest = try RestDuration(seconds: draft.restSeconds)
                let plannedSets = try draft.sets.map { set in
                    PlannedSet(
                        role: set.role,
                        prescription: try set.prescription(unit: unit),
                        side: set.side,
                        effortTarget: try set.effortTarget(),
                        tempo: try set.tempoDraft.value(),
                        restAfter: rest
                    )
                }

                return try PlannedExercise(
                    exercise: draft.catalog.definition,
                    sets: plannedSets,
                    group: try draft.groupID.map { groupID in
                        try ExerciseGroup(id: groupID, kind: draft.groupKind,
                                          position: exercises.filter { $0.groupID == groupID }.firstIndex(where: { $0.id == draft.id }) ?? 0)
                    }
                )
            }

            let plan = try WorkoutPlan(title: workoutTitle, exercises: plannedExercises)
            if await model.schedule(plan) {
                dismiss()
            } else {
                validationMessage = model.errorMessage
            }
        } catch {
            validationMessage = "Check the title, positive reps/time/distance, nonnegative weights/rest, and that rep ranges are in order."
        }
    }

}

private struct ManualExerciseDraft: Identifiable {
    let id = UUID()
    let catalog: CatalogExercise
    var sets: [ManualSetDraft]
    var restSeconds: Int
    var groupID: UUID?
    var groupKind: ExerciseGroupKind = .superset

    init(catalog: CatalogExercise, initialLoad: Double = 0) {
        self.catalog = catalog
        sets = (0 ..< catalog.defaultSets).map { _ in
            ManualSetDraft(catalog: catalog, initialLoad: initialLoad)
        }
        restSeconds = catalog.defaultRestSeconds
    }
}

enum ManualSetKind: String, CaseIterable {
    case weighted = "Weighted", bodyweight = "Bodyweight", assisted = "Assisted", amrap = "AMRAP", timed = "Timed", distance = "Distance"
}

struct ManualSetDraft: Identifiable {
    var id = UUID()
    var reps: Int
    var load: Double
    var seconds: Int
    var kind: ManualSetKind
    var role: SetRole = .working
    var side: ExerciseSide = .bilateral
    var usesRepRange = false
    var upperReps = 12
    var distance = 1.0
    var distanceUnit: DistanceUnit = .kilometers
    var includesDuration = false
    var includesLoad = false
    var effortKind = "None"
    var effort = 8.0
    var tempoDraft = SetTempoDraft()

    init(catalog: CatalogExercise, initialLoad: Double = 0) {
        reps = catalog.defaultReps
        load = initialLoad
        switch catalog.modality {
        case .weighted: kind = .weighted; seconds = 30
        case .bodyweight: kind = .bodyweight; seconds = 30
        case .assisted: kind = .assisted; seconds = 30
        case let .timed(value): kind = .timed; seconds = value
        }
    }

    func copy() -> ManualSetDraft {
        var duplicate = self
        duplicate.id = UUID()
        return duplicate
    }

    func effortTarget() throws -> EffortTarget? {
        switch effortKind {
        case "RPE": return .rpe(try RPE(Decimal(effort)))
        case "RIR": return .rir(try RIR(Int(effort)))
        default: return nil
        }
    }

    func prescription(unit: MassUnit) throws -> SetPrescription {
        let target: () throws -> RepTarget = {
            try usesRepRange ? RepTarget(lower: reps, upper: upperReps) : RepTarget(exact: reps)
        }
        let optionalLoad: () throws -> Load? = {
            try includesLoad ? Load(amount: Decimal(load), unit: unit) : nil
        }
        switch kind {
        case .weighted: return .weighted(reps: try target(), load: try Load(amount: Decimal(load), unit: unit))
        case .bodyweight: return .bodyweight(reps: try target())
        case .assisted: return .assistedBodyweight(reps: try target(), assistance: try Load(amount: Decimal(load), unit: unit))
        case .amrap: return .amrap(load: try optionalLoad())
        case .timed: return .timed(duration: try ExerciseDuration(seconds: seconds), load: try optionalLoad())
        case .distance: return .distance(distance: try ExerciseDistance(amount: Decimal(distance), unit: distanceUnit), durationTarget: try includesDuration ? ExerciseDuration(seconds: seconds) : nil)
        }
    }
}

private struct ManualExerciseSummaryRow: View {
    let exercise: ManualExerciseDraft
    let unit: MassUnit

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.catalog.name).font(.body.weight(.semibold))
                if exercise.groupID != nil {
                    Text(exercise.groupKind == .superset ? "Superset" : "Circuit")
                        .font(.caption).foregroundStyle(AppTheme.accentContent)
                }
            }
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.contentPrimary)
                .lineLimit(2)
            Spacer()
            Text(exercise.summary(unit: unit))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(AppTheme.contentSecondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityIdentifier("builder-exercise-summary-\(exercise.catalog.id)")
        }
        .frame(minHeight: 52)
        .accessibilityHint("Opens set and weight details. Swipe left to remove this exercise.")
    }
}

private extension ManualExerciseDraft {
    func summary(unit: MassUnit) -> String {
        if sets.contains(where: { $0.kind != sets.first?.kind || $0.usesRepRange || $0.role != .working || $0.side != .bilateral }) {
            return "\(sets.count) sets · customized"
        }
        if let kind = sets.first?.kind, kind == .amrap || kind == .assisted || kind == .distance {
            return "\(sets.count) sets · \(kind.rawValue)"
        }
        switch sets.first?.kind ?? .weighted {
        case .weighted:
            let repValues = Set(sets.map(\.reps))
            let loadValues = Set(sets.map(\.load))
            let repSummary = repValues.count == 1 ? "\(sets[0].reps) reps" : "varied reps"
            let loadSummary: String
            if loadValues.count == 1, let load = loadValues.first, load > 0 {
                loadSummary = " · \(load.formatted()) \(unit.rawValue)"
            } else if loadValues.contains(where: { $0 > 0 }) {
                loadSummary = " · varied weight"
            } else {
                loadSummary = ""
            }
            return "\(sets.count) sets × \(repSummary)\(loadSummary)"
        case .bodyweight:
            let repValues = Set(sets.map(\.reps))
            let target = repValues.count == 1 ? "\(sets[0].reps) reps" : "varied reps"
            return "\(sets.count) sets × \(target)"
        case .timed:
            let durations = Set(sets.map(\.seconds))
            let target = durations.count == 1 ? "\(sets[0].seconds) sec" : "varied time"
            return "\(sets.count) sets × \(target)"
        default: return "\(sets.count) sets"
        }
    }
}

private struct ManualExerciseDetailView: View {
    @Binding var exercise: ManualExerciseDraft
    let unit: MassUnit

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(exercise.catalog.equipment, systemImage: "dumbbell.fill")
                        Spacer()
                        Text(exercise.catalog.muscles.joined(separator: " · "))
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.contentTertiary)

                    Text(exercise.catalog.description)
                        .font(.body)
                        .foregroundStyle(AppTheme.contentSecondary)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(AppTheme.surfacePrimary)

            Section {
                ForEach($exercise.sets) { $set in
                    SetEditorRow(
                        position: exercise.sets.firstIndex(where: { $0.id == set.id }).map { $0 + 1 } ?? 1,
                        modality: exercise.catalog.modality,
                        unit: unit,
                        set: $set
                    )
                    .swipeActions(edge: .trailing) {
                        if exercise.sets.count > 1 {
                            Button("Delete", role: .destructive) {
                                removeSet(set.id)
                            }
                        }
                    }
                }

                Button {
                    addSet()
                } label: {
                    Label("Add set", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accentContent)
                        .frame(minHeight: 44)
                }
            } header: {
                Text("Sets")
                    .font(.caption.weight(.medium))
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.contentTertiary)
            } footer: {
                Text("Changing the first set's weight updates blank or matching sets below it. Customized sets stay unchanged. Swipe left to delete.")
                    .foregroundStyle(AppTheme.contentTertiary)
            }
            .listRowBackground(AppTheme.surfacePrimary)

            Section("Rest") {
                HStack {
                    Text("After each set")
                        .foregroundStyle(AppTheme.contentSecondary)
                    Spacer()
                    TextField("Seconds", value: $exercise.restSeconds, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppTheme.contentPrimary)
                        .padding(.horizontal, 10)
                        .frame(width: 72, height: 40)
                        .background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Rest seconds for \(exercise.catalog.name)")
                    Text("sec")
                        .font(.caption)
                        .foregroundStyle(AppTheme.contentTertiary)
                }
            }
            .listRowBackground(AppTheme.surfacePrimary)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle(exercise.catalog.name)
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppTheme.accentContent)
        .onChange(of: exercise.sets.first?.load) { oldValue, newValue in
            guard exercise.sets.first?.kind == .weighted,
                  let oldValue, let newValue else { return }
            let updatedLoads = SetLoadPropagation.replacingFirstLoad(
                in: exercise.sets.map(\.load),
                from: oldValue,
                to: newValue
            )
            for index in exercise.sets.indices where exercise.sets[index].kind == .weighted {
                exercise.sets[index].load = updatedLoads[index]
            }
        }
    }

    private func addSet() {
        let template = exercise.sets.last ?? ManualSetDraft(catalog: exercise.catalog)
        exercise.sets.append(template.copy())
    }

    private func removeSet(_ id: UUID) {
        guard exercise.sets.count > 1 else { return }
        exercise.sets.removeAll { $0.id == id }
    }
}

private struct SetEditorRow: View {
    let position: Int
    let modality: CatalogExerciseModality
    let unit: MassUnit
    @Binding var set: ManualSetDraft

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                Text("\(position)")
                    .font(.headline).foregroundStyle(AppTheme.contentTertiary)
                    .frame(width: 24).padding(.bottom, 10)
                switch set.kind {
                case .weighted, .assisted:
                    numericField("REPS", value: $set.reps)
                    decimalField(set.kind == .assisted ? "ASSISTANCE \(unit.rawValue.uppercased())" : "WEIGHT \(unit.rawValue.uppercased())", value: $set.load)
                case .bodyweight: numericField("REPS", value: $set.reps)
                case .timed: numericField("SECONDS", value: $set.seconds)
                case .distance: decimalField("DISTANCE", value: $set.distance)
                case .amrap: Text("As many reps as possible").font(.subheadline)
                }
            }
            DisclosureGroup("Set \(position) options") {
                VStack(spacing: 12) {
                    Picker("Type", selection: $set.kind) {
                        ForEach(ManualSetKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Role", selection: $set.role) {
                        Text("Working").tag(SetRole.working)
                        Text("Warm-up").tag(SetRole.warmUp)
                        Text("Drop").tag(SetRole.drop)
                        Text("Failure").tag(SetRole.failure)
                    }
                    Picker("Side", selection: $set.side) {
                        ForEach(ExerciseSide.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    if set.kind == .weighted || set.kind == .bodyweight || set.kind == .assisted {
                        Toggle("Rep range", isOn: $set.usesRepRange)
                        if set.usesRepRange { numericField("MAX REPS", value: $set.upperReps) }
                    }
                    if set.kind == .amrap || set.kind == .timed {
                        Toggle("Add weight", isOn: $set.includesLoad)
                        if set.includesLoad { decimalField("WEIGHT \(unit.rawValue.uppercased())", value: $set.load) }
                    }
                    if set.kind == .distance {
                        Picker("Distance unit", selection: $set.distanceUnit) {
                            ForEach(DistanceUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        Toggle("Duration target", isOn: $set.includesDuration)
                        if set.includesDuration { numericField("SECONDS", value: $set.seconds) }
                    }
                    Picker("Effort target", selection: $set.effortKind) {
                        ForEach(["None", "RPE", "RIR"], id: \.self) { Text($0) }
                    }
                    .onChange(of: set.effortKind) { _, kind in
                        if kind == "RIR" { set.effort = set.effort.rounded() }
                    }
                    if set.effortKind != "None" {
                        Stepper("\(set.effortKind) \(set.effort.formatted())", value: $set.effort, in: 0...10, step: set.effortKind == "RIR" ? 1 : 0.5)
                    }
                    SetTempoEditor(draft: $set.tempoDraft)
                }.padding(.top, 8)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
        .accessibilityHint("Swipe left to delete this set")
    }

    private func numericField(_ label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .tracking(0.8)
                .foregroundStyle(AppTheme.contentTertiary)
            TextField(label, value: value, format: .number)
                .keyboardType(.numberPad)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.contentPrimary)
                .multilineTextAlignment(.center)
                .frame(minHeight: 44)
                .background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel("Set \(position) \(label.lowercased())")
        }
    }

    private func decimalField(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .tracking(0.8)
                .foregroundStyle(AppTheme.contentTertiary)
            TextField(label, value: value, format: .number.precision(.fractionLength(0 ... 2)))
                .keyboardType(.decimalPad)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.contentPrimary)
                .multilineTextAlignment(.center)
                .frame(minHeight: 44)
                .background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel("Set \(position) \(label.lowercased())")
        }
    }
}

private struct ExerciseCatalogPicker: View {
    @Environment(\.dismiss) private var dismiss

    let selectedIDs: Set<Int>
    let onSelect: (CatalogExercise) -> Void

    @State private var query = ""
    @State private var addedIDs: Set<Int> = []

    private var visibleExercises: [CatalogExercise] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return ExerciseCatalog.exercises }

        return ExerciseCatalog.exercises.filter {
            $0.searchableText.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if visibleExercises.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(ExerciseCategory.allCases, id: \.self) { category in
                        let categoryExercises = visibleExercises.filter { $0.category == category }
                        if !categoryExercises.isEmpty {
                            Section {
                                ForEach(categoryExercises) { exercise in
                                    catalogRow(exercise)
                                }
                            } header: {
                                Text(category.rawValue)
                                    .font(.caption.weight(.medium))
                                    .tracking(1.1)
                                    .foregroundStyle(AppTheme.contentTertiary)
                            }
                            .listRowBackground(AppTheme.surfacePrimary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Exercise library")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search exercises or muscles")
            .tint(AppTheme.accentContent)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func catalogRow(_ exercise: CatalogExercise) -> some View {
        let isAdded = selectedIDs.contains(exercise.id) || addedIDs.contains(exercise.id)

        return Button {
            guard !isAdded else { return }
            onSelect(exercise)
            addedIDs.insert(exercise.id)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.contentPrimary)
                    Text("\(exercise.equipment) · \(exercise.defaultSets) × \(defaultTarget(for: exercise))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.contentTertiary)
                    Text(exercise.description)
                        .font(.caption)
                        .foregroundStyle(AppTheme.contentSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(isAdded ? .green : AppTheme.accentContent)
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
        .accessibilityIdentifier("exercise-\(exercise.id)")
    }

    private func defaultTarget(for exercise: CatalogExercise) -> String {
        switch exercise.modality {
        case .weighted, .bodyweight, .assisted:
            return "\(exercise.defaultReps) reps"
        case let .timed(defaultSeconds):
            return "\(defaultSeconds) sec"
        }
    }
}


private struct ManualGroupingEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var exercises: [ManualExerciseDraft]
    @State private var selected: Set<UUID> = []
    @State private var kind = ExerciseGroupKind.superset

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Group", selection: $kind) {
                        Text("Superset").tag(ExerciseGroupKind.superset)
                        Text("Circuit").tag(ExerciseGroupKind.circuit)
                    }
                    ForEach(exercises) { exercise in
                        Button {
                            if !selected.insert(exercise.id).inserted { selected.remove(exercise.id) }
                        } label: {
                            HStack {
                                Text(exercise.catalog.name)
                                Spacer()
                                if selected.contains(exercise.id) { Image(systemName: "checkmark") }
                            }.frame(minHeight: 44)
                        }
                        .accessibilityAddTraits(selected.contains(exercise.id) ? .isSelected : [])
                    }
                } footer: {
                    Text("Select two or more exercises. Each round follows the workout's exercise order. Rest remains configurable for each movement.")
                }
                Button("Group selected exercises") {
                    let id = UUID()
                    for index in exercises.indices where selected.contains(exercises[index].id) {
                        exercises[index].groupID = id
                        exercises[index].groupKind = kind
                    }
                    removeSingleMemberGroups()
                    dismiss()
                }.disabled(selected.count < 2)
                Button("Ungroup selected exercises") {
                    for index in exercises.indices where selected.contains(exercises[index].id) {
                        exercises[index].groupID = nil
                    }
                    removeSingleMemberGroups()
                    dismiss()
                }.disabled(selected.isEmpty)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Supersets & circuits")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }.tint(AppTheme.accentContent)
    }

    private func removeSingleMemberGroups() {
        let counts = Dictionary(grouping: exercises.compactMap(\.groupID), by: { $0 }).mapValues(\.count)
        for index in exercises.indices {
            if let id = exercises[index].groupID, counts[id] == 1 { exercises[index].groupID = nil }
        }
    }
}
