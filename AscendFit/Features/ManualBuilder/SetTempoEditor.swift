import SwiftUI

struct SetTempoDraft {
    var isEnabled = false
    var lowering = 3.0
    var bottomPause = 0.0
    var lifting = 1.0
    var topPause = 0.0
    var explosiveLift = false

    func value() throws -> Tempo? {
        guard isEnabled else { return nil }
        return try Tempo(
            eccentric: TempoPhase(seconds: Decimal(lowering)),
            bottomPause: TempoPhase(seconds: Decimal(bottomPause)),
            concentric: explosiveLift ? .explosive : TempoPhase(seconds: Decimal(lifting)),
            topPause: TempoPhase(seconds: Decimal(topPause))
        )
    }
}

struct SetTempoEditor: View {
    @Binding var draft: SetTempoDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Tempo target", isOn: $draft.isEnabled)
            if draft.isEnabled {
                phase("Lowering seconds", value: $draft.lowering)
                phase("Bottom pause seconds", value: $draft.bottomPause)
                Toggle("Explosive lift", isOn: $draft.explosiveLift)
                if !draft.explosiveLift { phase("Lifting seconds", value: $draft.lifting) }
                phase("Top pause seconds", value: $draft.topPause)
                Text("Lower → pause → lift → pause. These are planned timing cues, not a running timer.")
                    .font(.caption).foregroundStyle(AppTheme.contentSecondary)
            }
        }
    }

    private func phase(_ label: String, value: Binding<Double>) -> some View {
        Stepper("\(label): \(value.wrappedValue.formatted())", value: value, in: 0...30, step: 0.5)
    }
}
