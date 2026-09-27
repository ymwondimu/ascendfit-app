import SwiftUI

enum SetEffortKind: String, CaseIterable {
    case none = "None", rpe = "RPE", rir = "RIR"
}

struct SetDetailsDraft {
    var kind: SetEffortKind = .none
    var value = 8.0
    var notes = ""

    init(effort: EffortTarget? = nil, notes: String? = nil) {
        self.notes = notes ?? ""
        switch effort {
        case let .rpe(rpe): kind = .rpe; value = NSDecimalNumber(decimal: rpe.value).doubleValue
        case let .rir(rir): kind = .rir; value = Double(rir.value)
        case nil: break
        }
    }

    var effort: EffortTarget? {
        switch kind {
        case .none: nil
        case .rpe: try? .rpe(RPE(Decimal(value)))
        case .rir: try? .rir(RIR(Int(value)))
        }
    }

    var hasDetails: Bool { kind != .none || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

struct SetDetailsFields: View {
    @Binding var draft: SetDetailsDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Actual effort").font(.headline)
            Picker("Actual effort", selection: $draft.kind) {
                ForEach(SetEffortKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("actual-effort-kind")
            .onChange(of: draft.kind) { _, kind in
                if kind == .rir { draft.value = draft.value.rounded() }
            }
            if draft.kind != .none {
                Stepper("\(draft.kind.rawValue) \(draft.value.formatted())", value: $draft.value,
                        in: 0...10, step: draft.kind == .rir ? 1 : 0.5)
                    .accessibilityIdentifier("actual-effort-value")
                Text(draft.kind == .rpe ? "Rate how hard this set felt, from 0 to 10." : "How many more reps could you have completed?")
                    .font(.caption).foregroundStyle(AppTheme.contentSecondary)
            }
            Text("Set note").font(.headline)
            TextField("Optional note", text: $draft.notes, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("actual-set-notes")
            Text("Notes are saved as entered and included in your coach update.")
                .font(.caption).foregroundStyle(AppTheme.contentSecondary)
        }
    }
}
