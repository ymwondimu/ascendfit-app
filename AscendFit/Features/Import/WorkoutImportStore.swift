import Foundation

struct WorkoutImportStore {
    let directory: URL

    init(directory: URL? = nil) throws {
        if let directory { self.directory = directory }
        else {
            let base: URL
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                let testID = ProcessInfo.processInfo.environment["ASCEND_FIT_UI_TEST_STORE_ID"].flatMap(UUID.init(uuidString:)) ?? UUID()
                base = FileManager.default.temporaryDirectory.appendingPathComponent("AscendFitUITests-\(testID.uuidString)")
            } else {
                base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    .appendingPathComponent("AscendFit")
            }
            self.directory = base.appendingPathComponent("WorkoutImports")
        }
    }

    private var pendingURL: URL { directory.appendingPathComponent("pending.json") }

    func load() throws -> WorkoutImportDraft? {
        guard FileManager.default.fileExists(atPath: pendingURL.path) else { return nil }
        return try JSONDecoder().decode(WorkoutImportDraft.self, from: Data(contentsOf: pendingURL))
    }

    func save(_ draft: WorkoutImportDraft) throws {
        try write(draft, to: pendingURL)
    }

    func discardPending() throws {
        if FileManager.default.fileExists(atPath: pendingURL.path) { try FileManager.default.removeItem(at: pendingURL) }
    }

    func deleteAll() throws {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }

    private func write(_ draft: WorkoutImportDraft, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(draft)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

struct WorkoutJSONImporter {
    static let maximumBytes = 262_144

    static func decode(_ text: String, allowMultiple: Bool = false) throws -> WorkoutImportResponse {
        guard let data = text.data(using: .utf8), data.count <= maximumBytes else {
            throw WorkoutImportError.invalid("Choose a JSON workout smaller than 256 KB.")
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WorkoutImportError.invalid("Paste the workout JSON or choose a .json file first.")
        }
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let version = object["schemaVersion"] as? Int else {
                throw WorkoutImportError.invalid("This file needs a schemaVersion and the Ascend Fit workout envelope.")
            }
            guard version == 1 else { throw WorkoutImportError.invalid("Workout format version \(version) is not supported. Ask for schemaVersion 1.") }
            try WorkoutImportSchemaValidator.validate(data: data)
            var response = try JSONDecoder().decode(WorkoutImportResponse.self, from: data)
            guard ["none", "single", "multiple"].contains(response.classification),
                  response.workouts.count <= 20,
                  (response.classification != "single" || response.workouts.count == 1),
                  (response.classification != "none" || response.workouts.isEmpty),
                  (response.classification != "multiple" || response.workouts.count > 1) else {
                throw WorkoutImportError.invalid("The workout count does not match its classification.")
            }
            guard allowMultiple || response.classification != "multiple" else {
                throw WorkoutImportError.invalid("This version imports one definite workout at a time. Ask your coach for a file containing only the workout you want to train.")
            }
            response.source = WorkoutImportSource(kind: "workoutPlanFile", originalText: text, sourceURL: nil)
            return response
        } catch let error as WorkoutImportError { throw error }
        catch let DecodingError.keyNotFound(key, context) {
            throw WorkoutImportError.invalid("Missing JSON field '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: ".")). Ask your coach to use the supplied format.")
        } catch {
            throw WorkoutImportError.invalid("This is not valid Ascend Fit JSON. Use the complete JSON object, without Markdown fences, and check the required fields and value types.")
        }
    }

    static func readFile(_ url: URL) throws -> String {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        guard url.pathExtension.lowercased() == "json" else { throw WorkoutImportError.invalid("Choose a .json workout file.") }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maximumBytes else { throw WorkoutImportError.invalid("Choose a JSON workout smaller than 256 KB.") }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes, let text = String(data: data, encoding: .utf8) else {
            throw WorkoutImportError.invalid("Choose a UTF-8 JSON file smaller than 256 KB.")
        }
        return text
    }
}

// Persist the app draft before acknowledging the cross-process handoff. If the
// acknowledgement fails, its ID makes reopening retry-safe without replacing edits.
extension WorkoutImportStore {
    func receiveSharedWorkout(from inbox: SharedWorkoutInbox) throws -> WorkoutImportDraft? {
        if let existing = try load() {
            if let id = existing.sharedPayloadID { try inbox.remove(id: id) }
            if !existing.originalText.isEmpty || existing.response != nil { return existing }
        }
        guard let payload = try inbox.peek() else { return try load() }
        var draft = WorkoutImportDraft()
        draft.originalText = payload.text
        draft.sourceKind = .shareSheet
        draft.sourceURL = payload.sourceURL
        draft.sharedPayloadID = payload.id
        try save(draft)
        try inbox.remove(id: payload.id)
        return draft
    }
}

struct AppSharedWorkoutInbox {
    static func open() throws -> SharedWorkoutInbox {
        #if ASCEND_FIT_PERSONAL
        return SharedWorkoutInbox(directory: try WorkoutImportStore().directory.appendingPathComponent("SharedInbox"))
        #else
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
           !ProcessInfo.processInfo.arguments.contains("--ui-testing-share-host") {
            return SharedWorkoutInbox(directory: try WorkoutImportStore().directory.appendingPathComponent("SharedInbox"))
        }
        return SharedWorkoutInbox(directory: try SharedWorkoutInbox.defaultDirectory())
        #endif
    }
}
