import Foundation
import Testing
@testable import AscendFit

struct SharedWorkoutHandoffTests {
    @Test("Shared handoff persists exact source before removal and never replaces an existing draft")
    func transfer() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let inbox = SharedWorkoutInbox(directory: base.appendingPathComponent("inbox"))
        let store = try WorkoutImportStore(directory: base.appendingPathComponent("draft"))
        let sourceURL = URL(string: "https://example.com/workout")!
        let first = try inbox.enqueue(text: "  first workout\n", sourceURL: sourceURL)
        let loaded = try store.receiveSharedWorkout(from: inbox)
        let received = try #require(loaded)
        #expect(received.originalText == first.text)
        #expect(received.sourceKind == .shareSheet)
        #expect(received.sourceURL == sourceURL)
        #expect(try inbox.peek() == nil)
        var edited = received
        edited.originalText = "edited draft"
        try store.save(edited)
        let next = try inbox.enqueue(text: "next workout", sourceURL: nil)
        #expect(try store.receiveSharedWorkout(from: inbox)?.originalText == "edited draft")
        #expect(try inbox.peek()?.id == next.id)
        // Simulate a crash after the draft write but before acknowledgement.
        _ = try inbox.enqueue(text: first.text, sourceURL: sourceURL)
        edited.sharedPayloadID = next.id
        try store.save(edited)
        #expect(try store.receiveSharedWorkout(from: inbox)?.originalText == "edited draft")
        #expect(try inbox.peek()?.text == first.text)
        try store.deleteAll()
        try inbox.deleteAll()
        #expect(try store.load() == nil)
        #expect(try inbox.peek() == nil)
    }
}
