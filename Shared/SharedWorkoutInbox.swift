import Foundation
import Darwin

struct SharedWorkoutPayload: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let text: String
    let sourceURL: URL?
    let receivedAt: Date
}

enum SharedWorkoutInboxError: Error, LocalizedError {
    case unavailable, empty, oversized, full
    var errorDescription: String? {
        switch self {
        case .unavailable: "Shared storage is unavailable. Open Ascend Fit once, then try sharing again."
        case .empty: "Share the workout text or a JSON file instead of an empty item."
        case .oversized: "This workout is too large. Share a single workout under 256 KB."
        case .full: "Your shared workout inbox is full. Review or remove saved shares in Ascend Fit, then try again."
        }
    }
}

/// A bounded, cross-process inbox. Reading removes only expired items; acceptance is explicit.
struct SharedWorkoutInbox: Sendable {
    static let groupIdentifier = "group.com.ymwondimu.ascendfit.app"
    static let maximumBytes = 256 * 1024
    static let maximumCount = 20
    static let lifetime: TimeInterval = 7 * 24 * 60 * 60
    let directory: URL

    static func defaultDirectory() throws -> URL {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) else {
            throw SharedWorkoutInboxError.unavailable
        }
        return container.appendingPathComponent("WorkoutInbox", isDirectory: true)
    }

    func enqueue(text: String, sourceURL: URL? = nil, now: Date = Date()) throws -> SharedWorkoutPayload {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SharedWorkoutInboxError.empty }
        guard text.utf8.count <= Self.maximumBytes else { throw SharedWorkoutInboxError.oversized }
        return try locked {
            let items = try current(now: now)
            if let duplicate = items.first(where: { $0.text == text && $0.sourceURL == sourceURL }) { return duplicate }
            guard items.count < Self.maximumCount else { throw SharedWorkoutInboxError.full }
            let item = SharedWorkoutPayload(id: UUID(), text: text, sourceURL: sourceURL, receivedAt: now)
            let data = try JSONEncoder().encode(item)
            try data.write(to: file(item.id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return item
        }
    }

    func peek(now: Date = Date()) throws -> SharedWorkoutPayload? { try locked { try current(now: now).first } }
    func remove(id: UUID) throws {
        try locked { if FileManager.default.fileExists(atPath: file(id).path) { try FileManager.default.removeItem(at: file(id)) } }
    }
    func deleteAll() throws {
        try locked {
            for url in try payloadFiles() { try FileManager.default.removeItem(at: url) }
        }
    }

    private func file(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString).appendingPathExtension("json") }
    private func payloadFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
    }
    private func current(now: Date) throws -> [SharedWorkoutPayload] {
        var items: [SharedWorkoutPayload] = []
        for url in try payloadFiles() {
            let item = try JSONDecoder().decode(SharedWorkoutPayload.self, from: Data(contentsOf: url))
            if now.timeIntervalSince(item.receivedAt) >= Self.lifetime { try FileManager.default.removeItem(at: url) }
            else { items.append(item) }
        }
        return items.sorted { $0.receivedAt == $1.receivedAt ? $0.id.uuidString < $1.id.uuidString : $0.receivedAt < $1.receivedAt }
    }
    private func locked<T>(_ action: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        let descriptor = open(directory.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw SharedWorkoutInboxError.unavailable }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw SharedWorkoutInboxError.unavailable }
        defer { flock(descriptor, LOCK_UN) }
        return try action()
    }
}
