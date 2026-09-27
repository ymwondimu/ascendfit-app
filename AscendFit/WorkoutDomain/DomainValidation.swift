import Foundation

enum DomainValidationError: Error, Equatable, Sendable {
    case empty(field: String)
    case outOfRange(field: String)
    case invalidRange(field: String)
    case unsupportedSchemaVersion(Int)
    case invalidTransition(from: String, command: String)
    case unknownPlannedSet(UUID)
    case unknownPlannedExercise(UUID)
    case unknownCompletedSet(UUID)
    case alreadyCompleted(UUID)
    case alreadySkipped(UUID)
    case nothingToUndo
    case summaryUnavailable
    case nonChronologicalEvent
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
