import Foundation
import Testing
@testable import AscendFit

struct SharedWorkoutInboxTests {
    @Test("Exact repeated shares reuse an identity; consuming one preserves others and expiry frees space")
    func duplicateAndExpiry() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let inbox = SharedWorkoutInbox(directory: directory)
        let now = Date(timeIntervalSince1970: 1_000)
        let first = try inbox.enqueue(text: "  Workout\n", now: now)
        #expect(try inbox.enqueue(text: "  Workout\n", now: now.addingTimeInterval(10)).id == first.id)
        let second = try inbox.enqueue(text: "Other", sourceURL: URL(string: "https://example.com"), now: now.addingTimeInterval(1))
        try inbox.remove(id: first.id)
        #expect(try inbox.peek(now: now.addingTimeInterval(2)) == second)
        #expect(try inbox.peek(now: now.addingTimeInterval(SharedWorkoutInbox.lifetime + 1)) == nil)
    }

    @Test("A full or oversized inbox rejects new work without dropping pending shares")
    func bounds() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let inbox = SharedWorkoutInbox(directory: directory)
        let now = Date()
        let first = try inbox.enqueue(text: "Workout 0", now: now)
        for index in 1..<SharedWorkoutInbox.maximumCount { _ = try inbox.enqueue(text: "Workout \(index)", now: now.addingTimeInterval(Double(index))) }
        #expect(throws: SharedWorkoutInboxError.self) { try inbox.enqueue(text: "Extra", now: now) }
        #expect(try inbox.enqueue(text: first.text, now: now).id == first.id)
        #expect(throws: SharedWorkoutInboxError.self) { try inbox.enqueue(text: String(repeating: "a", count: SharedWorkoutInbox.maximumBytes + 1), now: now) }
        #expect(try inbox.peek(now: now)?.id == first.id)
        try inbox.deleteAll()
        #expect(try inbox.peek(now: now) == nil)
    }
}
