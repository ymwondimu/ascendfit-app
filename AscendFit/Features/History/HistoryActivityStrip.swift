import SwiftUI

struct HistoryActivityStrip: View {
    let history: [WorkoutHistoryEntry]
    @Binding var selectedDate: Date
    @Binding var filterByDate: Bool
    @State private var unit = MassUnit.pounds

    var body: some View {
        let window = HistoryActivityWindow(history: history)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Last 12 weeks").font(.headline)
                Spacer()
                Picker("Volume unit", selection: $unit) {
                    ForEach(MassUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("history-volume-unit")
            }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 2) {
                    ForEach(0..<12, id: \.self) { week in
                        VStack(spacing: 2) {
                            Text(window.days[week * 7].date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption2).lineLimit(1).accessibilityHidden(true)
                            ForEach(Array(window.days[(week * 7)..<(week * 7 + 7)])) { day in
                                dayButton(day, window: window)
                            }
                        }
                    }
                }
            }
            .defaultScrollAnchor(.trailing)
            Text("Stronger color shows higher daily load volume in \(unit.rawValue), grouped into quartiles. A dot marks a workout. Tap a day to filter.")
                .font(.caption).foregroundStyle(AppTheme.contentSecondary)
            if filterByDate {
                Button("Show all dates") { filterByDate = false }
                    .accessibilityIdentifier("history-clear-date")
            }
        }
    }

    private func dayButton(_ day: HistoryActivityDay, window: HistoryActivityWindow) -> some View {
        let intensity = window.intensity(for: day, unit: unit)
        let selected = filterByDate && Calendar.current.isDate(day.date, inSameDayAs: selectedDate)
        return Button {
            selectedDate = day.date
            filterByDate = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(intensity == 0 ? AppTheme.surfaceSecondary : AppTheme.accentContent.opacity(Double(intensity) / 4))
                    .frame(width: 32, height: 32)
                if day.workoutCount > 0 {
                    Circle().fill(AppTheme.contentPrimary).frame(width: 5, height: 5)
                }
                if selected {
                    RoundedRectangle(cornerRadius: 7).stroke(AppTheme.contentPrimary, lineWidth: 2)
                        .frame(width: 36, height: 36)
                }
            }
            .frame(width: 44, height: 44)
            .opacity(day.isFuture ? 0.25 : 1)
        }
        .buttonStyle(.plain)
        .disabled(day.isFuture)
        .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
        .accessibilityValue("\(day.workoutCount) workouts. \((day.volumes[unit] ?? 0).formatted()) \(unit.rawValue) load volume.\(selected ? " Selected." : "")")
        .accessibilityHint("Show workouts from this day")
        .accessibilityIdentifier("history-day-\(Calendar.current.startOfDay(for: day.date).timeIntervalSince1970)")
    }
}
