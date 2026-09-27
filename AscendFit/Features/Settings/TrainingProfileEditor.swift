import SwiftUI

struct TrainingProfileEditor: View {
    @Environment(\.dismiss) private var dismiss

    let unit: MassUnit
    let onSave: (TrainingProfile) -> Void

    @State private var heightText: String
    @State private var bodyWeightText: String
    @State private var sex: TrainingSex
    @State private var experience: TrainingExperience

    init(
        unit: MassUnit,
        profile: TrainingProfile?,
        onSave: @escaping (TrainingProfile) -> Void
    ) {
        self.unit = unit
        self.onSave = onSave

        let displayedHeight: Double?
        let displayedWeight: Double?
        if let profile {
            displayedHeight = unit == .pounds
                ? profile.heightCentimeters / 2.54
                : profile.heightCentimeters
            displayedWeight = unit == .pounds
                ? profile.bodyWeightKilograms * 2.204_622_621_8
                : profile.bodyWeightKilograms
        } else {
            displayedHeight = nil
            displayedWeight = nil
        }

        _heightText = State(initialValue: displayedHeight.map {
            $0.formatted(.number.precision(.fractionLength(0 ... 1)))
        } ?? "")
        _bodyWeightText = State(initialValue: displayedWeight.map {
            $0.formatted(.number.precision(.fractionLength(0 ... 1)))
        } ?? "")
        _sex = State(initialValue: profile?.sex ?? .preferNotToSay)
        _experience = State(initialValue: profile?.experience ?? .beginner)
    }

    private var parsedHeight: Double? {
        Double(heightText.replacingOccurrences(of: ",", with: "."))
    }

    private var parsedBodyWeight: Double? {
        Double(bodyWeightText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        guard let parsedHeight, let parsedBodyWeight else { return false }
        return parsedHeight > 0 && parsedBodyWeight > 0
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    profileField(
                        "Height",
                        unitLabel: unit == .pounds ? "in" : "cm",
                        text: $heightText
                    )
                    profileField(
                        "Body weight",
                        unitLabel: unit.rawValue,
                        text: $bodyWeightText
                    )
                }
                .listRowBackground(AppTheme.surfacePrimary)

                Section("About you") {
                    Picker("Sex", selection: $sex) {
                        ForEach(TrainingSex.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }
                .listRowBackground(AppTheme.surfacePrimary)

                Section("Experience") {
                    Picker("Experience", selection: $experience) {
                        ForEach(TrainingExperience.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(AppTheme.surfacePrimary)

                Section {
                    Label(
                        "Starting weights are estimates, not strength assessments. Lower any value that does not feel controlled and comfortable.",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(AppTheme.contentSecondary)
                }
                .listRowBackground(AppTheme.surfacePrimary)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Training profile")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accentContent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                        .foregroundStyle(AppTheme.accentContent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundStyle(AppTheme.accentContent)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func profileField(
        _ label: String,
        unitLabel: String,
        text: Binding<String>
    ) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(AppTheme.contentPrimary)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .frame(width: 90)
                .accessibilityLabel("\(label) in \(unitLabel)")
            Text(unitLabel)
                .font(.caption)
                .foregroundStyle(AppTheme.contentTertiary)
                .frame(width: 24, alignment: .leading)
        }
        .frame(minHeight: 44)
    }

    private func save() {
        guard let parsedHeight, let parsedBodyWeight else { return }

        let heightCentimeters = unit == .pounds ? parsedHeight * 2.54 : parsedHeight
        let bodyWeightKilograms = unit == .pounds
            ? parsedBodyWeight / 2.204_622_621_8
            : parsedBodyWeight
        onSave(
            TrainingProfile(
                sex: sex,
                heightCentimeters: heightCentimeters,
                bodyWeightKilograms: bodyWeightKilograms,
                experience: experience
            )
        )
        dismiss()
    }
}
