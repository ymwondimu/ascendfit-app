import Foundation
import Testing
@testable import AscendFit

struct WorkoutTextInterpreterTests {
    private func config() throws -> WorkoutTextServiceConfiguration {
        try .init(baseURL: URL(string: "https://example.com")!, accessToken: "private-test-token")
    }
    private func response(_ request: URLRequest, status: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
    }

    @Test("Conversion sends only explicit source and validates the canonical response with exact provenance")
    func requestAndResponse() async throws {
        let text = "  Back squat: 145 lb × 8 × 1\n"
        let config = try config()
        let interpreter = WorkoutTextInterpreter(configuration: config) { request in
            #expect(request.url == config.endpoint)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer private-test-token")
            let input = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            #expect(Set(input.keys) == ["schemaVersion", "text", "sourceKind", "sourceURL"])
            #expect(input["text"] as? String == text)
            let body: [String: Any] = ["schemaVersion": 1, "classification": "none", "workouts": [], "issues": [], "confidence": [],
                "source": ["kind": "paste", "originalText": text, "sourceURL": NSNull()]]
            return (try JSONSerialization.data(withJSONObject: body), response(request))
        }
        let result = try await interpreter.interpret(text: text, kind: .paste, sourceURL: nil)
        #expect(result.source?.originalText == text)
        #expect(result.classification == "none")
        let invalid = WorkoutTextInterpreter(configuration: config) { request in
            let body: [String: Any] = ["schemaVersion": 1, "classification": "none", "workouts": [], "issues": [], "confidence": [],
                "source": ["kind": "paste", "originalText": text.trimmingCharacters(in: .whitespacesAndNewlines), "sourceURL": NSNull()]]
            return (try JSONSerialization.data(withJSONObject: body), response(request))
        }
        await #expect(throws: WorkoutImportError.self) { try await invalid.interpret(text: text, kind: .paste, sourceURL: nil) }
    }

    @Test("Private access requires HTTPS; invalid source never reaches transport and error bodies are not surfaced")
    func boundaries() async throws {
        #expect(throws: WorkoutImportError.self) { try WorkoutTextServiceConfiguration(baseURL: URL(string: "http://example.com")!, accessToken: "token") }
        #expect(throws: WorkoutImportError.self) { try WorkoutTextServiceConfiguration(baseURL: URL(string: "https://user:pass@example.com")!, accessToken: "token") }
        let interpreter = WorkoutTextInterpreter(configuration: try config()) { request in
            (Data("private server details must not appear".utf8), response(request, status: 429))
        }
        do { _ = try await interpreter.interpret(text: "Squat", kind: .paste, sourceURL: nil); Issue.record("Expected limit error") }
        catch { #expect(error.localizedDescription.contains("limit")); #expect(!error.localizedDescription.contains("private server details")) }
        let unused = WorkoutTextInterpreter(configuration: try config()) { _ in
            Issue.record("Invalid input reached transport")
            throw URLError(.badURL)
        }
        await #expect(throws: WorkoutImportError.self) { try await unused.interpret(text: String(repeating: "a", count: 12_001), kind: .paste, sourceURL: nil) }
    }

    @Test("Cancellation remains cancellation and multiple workouts require explicit selection")
    func cancellationAndSelection() async throws {
        let cancelled = WorkoutTextInterpreter(configuration: try config()) { _ in throw CancellationError() }
        await #expect(throws: CancellationError.self) { try await cancelled.interpret(text: "Squat", kind: .paste, sourceURL: nil) }
        let bundle = Bundle(for: InterpreterFixtures.self)
        let url = try #require(bundle.url(forResource: "lower-a-ready.workout", withExtension: "json"))
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        var workouts = object["workouts"] as! [[String: Any]]
        var second = workouts[0]; second["id"] = UUID().uuidString; second["title"] = "Another workout"
        workouts.append(second); object["workouts"] = workouts; object["classification"] = "multiple"
        let json = String(data: try JSONSerialization.data(withJSONObject: object), encoding: .utf8)!
        #expect(throws: WorkoutImportError.self) { try WorkoutJSONImporter.decode(json) }
        var draft = WorkoutImportDraft()
        draft.response = try WorkoutJSONImporter.decode(json, allowMultiple: true)
        #expect(draft.selectedIndex == nil)
        #expect(throws: WorkoutImportError.self) { try draft.makePlan() }
        draft.selectedWorkoutID = second["id"].flatMap { UUID(uuidString: $0 as! String) }
        #expect(draft.selectedIndex == 1)
    }
}
private final class InterpreterFixtures: NSObject {}
