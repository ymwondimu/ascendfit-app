import SwiftUI

struct OnboardingView: View {
    let onComplete: (TrainingProfile, MassUnit) -> Void

    @State private var unit = MassUnit.pounds
    @State private var sex = TrainingSex.preferNotToSay
    @State private var heightText = ""
    @State private var bodyWeightText = ""
    @State private var experience = TrainingExperience.beginner

    private var parsedHeight: Double? {
        Double(heightText.replacingOccurrences(of: ",", with: "."))
    }

    private var parsedBodyWeight: Double? {
        Double(bodyWeightText.replacingOccurrences(of: ",", with: "."))
    }

    private var canContinue: Bool {
        guard let parsedHeight, let parsedBodyWeight else { return false }
        return parsedHeight > 0 && parsedBodyWeight > 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(AppTheme.action)
                        .frame(width: 62, height: 62)
                        .background(AppTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 20))
                    CampaignScreenIntro(eyebrow: "Welcome to Ascend", title: "Set your baseline.", subtitle: "Choose units and add your profile once. Every suggested starting weight remains editable.")
                }

                VStack(spacing: 0) {
                    profileRow("Units") {
                        Picker("Units", selection: $unit) {
                            Text("lb / in").tag(MassUnit.pounds)
                            Text("kg / cm").tag(MassUnit.kilograms)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }

                    divider

                    profileRow("Sex") {
                        Picker("Sex", selection: $sex) {
                            ForEach(TrainingSex.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    divider

                    profileRow("Height") {
                        measurementField(
                            text: $heightText,
                            unit: unit == .pounds ? "in" : "cm",
                            accessibilityLabel: "Height"
                        )
                    }

                    divider

                    profileRow("Body weight") {
                        measurementField(
                            text: $bodyWeightText,
                            unit: unit.rawValue,
                            accessibilityLabel: "Body weight"
                        )
                    }
                }
                .padding(.horizontal, 16)
                .background(AppTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 12) {
                    Text("LIFTING EXPERIENCE")
                        .font(.caption.weight(.medium))
                        .tracking(1.1)
                        .foregroundStyle(AppTheme.contentTertiary)
                    Picker("Lifting experience", selection: $experience) {
                        ForEach(TrainingExperience.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(spacing: 12) {
                    Button("Continue", action: complete)
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(!canContinue)

                    Text("Starting weights are estimates—not strength assessments or medical advice. Every suggested value remains editable.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.contentTertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.screenInset)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.background.ignoresSafeArea())
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.contentTertiary.opacity(0.18))
            .frame(height: 0.5)
            .padding(.leading, 4)
    }

    private func profileRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(AppTheme.contentPrimary)
            Spacer()
            content()
        }
        .frame(minHeight: 60)
    }

    private func measurementField(
        text: Binding<String>,
        unit: String,
        accessibilityLabel: String
    ) -> some View {
        HStack(spacing: 6) {
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .frame(width: 72)
                .accessibilityLabel("\(accessibilityLabel), \(unit)")
            Text(unit)
                .font(.caption)
                .foregroundStyle(AppTheme.contentTertiary)
                .frame(width: 24, alignment: .leading)
        }
    }

    private func complete() {
        guard let parsedHeight, let parsedBodyWeight else { return }

        let heightCentimeters = unit == .pounds ? parsedHeight * 2.54 : parsedHeight
        let bodyWeightKilograms = unit == .pounds
            ? parsedBodyWeight / 2.204_622_621_8
            : parsedBodyWeight
        onComplete(
            TrainingProfile(
                sex: sex,
                heightCentimeters: heightCentimeters,
                bodyWeightKilograms: bodyWeightKilograms,
                experience: experience
            ),
            unit
        )
    }
}
