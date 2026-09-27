import SwiftUI
import UniformTypeIdentifiers

/// Shared by a workout's overflow menu, History, and Settings.
struct WorkoutExportActions: View {
    let entries: [WorkoutHistoryEntry]

    var body: some View {
        ShareLink(item: WorkoutJSONFile(entries: entries), preview: SharePreview("Ascend Fit workout data")) {
            Label("Export JSON", systemImage: "doc")
        }
        .accessibilityIdentifier("export-workouts-json")
        ShareLink(item: WorkoutCSVFile(entries: entries), preview: SharePreview("Ascend Fit workout sets")) {
            Label("Export CSV", systemImage: "tablecells")
        }
        .accessibilityIdentifier("export-workouts-csv")
    }
}

private struct WorkoutJSONFile: Transferable, Sendable {
    let entries: [WorkoutHistoryEntry]
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { item in
            try WorkoutDataExport(entries: item.entries).jsonData()
        }
        .suggestedFileName("ascend-fit-workouts.json")
    }
}

private struct WorkoutCSVFile: Transferable, Sendable {
    let entries: [WorkoutHistoryEntry]
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { item in
            try WorkoutDataExport(entries: item.entries).csvData()
        }
        .suggestedFileName("ascend-fit-sets.csv")
    }
}
