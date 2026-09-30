import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImportWorkoutView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = WorkoutImportDraft()
    @State private var store: WorkoutImportStore?
    @State private var message: String?
    @State private var storageFailed = false
    @State private var isLoading = true
    @State private var isParsing = false
    @State private var isSaving = false
    @State private var importTask: Task<Void, Never>?
    @State private var showingFilePicker = false
    @State private var showingFormat = false
    @State private var confirmReplace = false
    @State private var sharedWaiting = false
    @State private var confirmShared = false
    @State private var confirmConversion = false
    @FocusState private var isEditingSource: Bool

    var body: some View {
        Group {
            if isLoading { ProgressView("Opening import draft…") }
            else if draft.selectedIndex != nil { review }
            else { capture }
        }
        .navigationTitle(draft.selectedIndex == nil ? "Import workout" : "Review workout")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.background)
        .tint(AppTheme.accentContent)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { importTask?.cancel(); dismiss() }.disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Format help") { showingFormat = true }.disabled(isSaving)
            }
        }
        .sheet(isPresented: $showingFormat) { WorkoutImportFormatHelp() }
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.json]) { result in
            do {
                let text = try WorkoutJSONImporter.readFile(result.get())
                setSource(text, kind: .workoutPlanFile)
                parse()
            } catch { message = error.localizedDescription }
        }
        .confirmationDialog("Replace the workout on Today?", isPresented: $confirmReplace, titleVisibility: .visible) {
            Button("Replace with reviewed workout") { Task { await savePlan() } }
        } message: { Text("Your existing unstarted plan will be replaced only after this import saves successfully.") }
        .confirmationDialog("Discard this import draft and open the shared workout?", isPresented: $confirmShared, titleVisibility: .visible) {
            Button("Discard draft and open shared workout", role: .destructive) {
                do {
                    try store?.discardPending()
                    try loadSharedDraft()
                } catch { message = error.localizedDescription }
            }
        }
        .confirmationDialog("Convert this workout text?", isPresented: $confirmConversion, titleVisibility: .visible) {
            Button("Send text and convert") { parse(asText: true) }
        } message: {
            Text("Only this draft’s workout text and source link will be sent to the configured import service and its AI provider. Your profile and workout history are not sent. Review the returned targets before adding to Today.")
        }
        .interactiveDismissDisabled(isSaving)
        .task {
            guard isLoading else { return }
            do {
                let store = try WorkoutImportStore()
                self.store = store
                if let restored = try store.load() { draft = restored }
                do { try loadSharedDraft() }
                catch { message = "Shared workouts could not be opened. Your saved import draft is unchanged. Try reopening import." }
            } catch {
                message = "The saved import draft could not be opened. Your workout data has not changed."
                storageFailed = true
            }
            if draft.inputMode == nil, draft.sourceKind == .shareSheet,
               !draft.originalText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
                draft.inputMode = .text
            }
            isLoading = false
        }
        .onDisappear { importTask?.cancel() }
    }

    private var capture: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CampaignScreenIntro(eyebrow: "From your coach", title: "Import workout", subtitle: "Bring a ready plan into Ascend and review it before training.")
                sharedNotice
                Picker("Workout format", selection: Binding(get: { mode }, set: { draft.inputMode = $0; persist() })) {
                    Text("JSON").tag(WorkoutImportInputMode.json)
                    Text("Workout text").tag(WorkoutImportInputMode.text)
                }.pickerStyle(.segmented).disabled(isParsing)
                Text(mode == .json ? "Paste Ascend Fit workout JSON from ChatGPT or choose a .json file. JSON is validated entirely on your device." : "Paste the workout exactly as your coach wrote it. Conversion needs a configured service and an internet connection; your text is saved locally first.")
                    .foregroundStyle(AppTheme.contentSecondary)
                HStack {
                    Button(mode == .json ? "Paste JSON" : "Paste text", systemImage: "doc.on.clipboard") {
                        if let text = UIPasteboard.general.string { setSource(text, kind: .paste) }
                        else { message = "The clipboard does not contain text." }
                    }.accessibilityIdentifier("import-paste")
                    Spacer()
                    Button("Choose file", systemImage: "doc") { showingFilePicker = true }
                }.frame(minHeight: 44).disabled(isParsing)
                TextEditor(text: Binding(get: { draft.originalText }, set: { setSource($0, kind: .paste) }))
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 240)
                    .padding(8).background(AppTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 16))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .focused($isEditingSource)
                    .accessibilityIdentifier("import-source")
                    .disabled(isParsing)
                if let response = draft.response, response.classification == "multiple" {
                    Text("Choose one workout to review").font(.headline)
                    ForEach(response.workouts) { workout in
                        Button(draft.title(for: workout)) { draft.selectedWorkoutID = workout.id; persist() }
                    }
                }
                statusMessage
                Text(mode == .json ? "Only explicit paste reads your clipboard. Closing keeps this draft locally. JSON review sends nothing to a server." : "Closing keeps your text locally. Conversion sends only this draft after your explicit confirmation; it never runs automatically on reopening.")
                    .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                if storageFailed {
                    Button("Discard unreadable import draft", role: .destructive) {
                        do {
                            guard let store else { throw WorkoutImportError.invalid("Local storage is unavailable.") }
                            try store.discardPending(); draft = WorkoutImportDraft(); storageFailed = false; message = nil
                        }
                        catch { message = "The draft could not be cleared. Try reopening import." }
                    }
                }
            }.padding(AppTheme.Spacing.screenInset)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            captureAction
                .padding(AppTheme.Spacing.screenInset)
                .background(AppTheme.background)
        }
    }

    @ViewBuilder private var captureAction: some View {
        if isParsing {
            ProgressView(mode == .json ? "Checking workout details…" : "Converting workout text…")
            Button(mode == .json ? "Cancel checking" : "Cancel conversion") { importTask?.cancel(); isParsing = false }
        } else {
            Button(mode == .json ? "Review JSON" : "Convert workout text") {
                if mode == .json { parse() }
                else { confirmConversion = true }
            }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(draft.originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || storageFailed)
                .accessibilityIdentifier("import-review-json")
        }
    }

    private var review: some View {
        List {
            if let index = draft.selectedIndex, let response = draft.response {
                Section {
                    CampaignScreenIntro(eyebrow: "Check the plan", title: "Review workout", subtitle: "Confirm every target before this becomes today's session.")
                    sharedNotice
                    TextField("Workout name", text: Binding(
                        get: { draft.response.map { draft.title(for: $0.workouts[index]) } ?? "" },
                        set: {
                            if let workout = draft.response?.workouts[index] { draft.setTitle($0, for: workout); persist() }
                        }
                    ))
                    Text("Named from the exercises. Edit this name to save your own title.")
                        .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                    TextField("Workout notes", text: Binding(
                        get: { draft.response?.workouts[index].notes ?? "" },
                        set: { draft.response?.workouts[index].notes = $0; persist() }
                    ), axis: .vertical)
                    Text("\(response.workouts[index].exercises.count) \(response.workouts[index].exercises.count == 1 ? "exercise" : "exercises") · review every target before training")
                        .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                    issueRows(prefix: "/workouts/\(index)", includeChildren: false)
                    let unmatched = response.workouts[index].exercises.filter { draft.definition(for: $0) == nil }
                    if !unmatched.isEmpty {
                        Text("\(unmatched.count) exercise names are outside the library. You can keep their exact names without choosing a different movement.")
                            .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                        Button("Keep \(unmatched.count) names as custom exercises") {
                            do {
                                for exercise in unmatched {
                                    draft.exerciseMappings[exercise.id] = try ExerciseDefinition(name: exercise.name, equipment: exercise.equipment)
                                }
                                persist()
                            } catch { message = error.localizedDescription }
                        }
                        .accessibilityIdentifier("import-keep-custom-names")
                    }

                }
                ForEach(Array(response.workouts[index].exercises.enumerated()), id: \.element.id) { exerciseIndex, exercise in
                    Section {
                        NavigationLink {
                            ImportedExerciseEditor(exercise: exerciseBinding(workout: index, exercise: exerciseIndex),
                                                   mapped: draft.definition(for: exercise)) { definition in
                                draft.exerciseMappings[exercise.id] = definition
                                persist()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(draft.definition(for: exercise)?.name ?? exercise.name).font(.headline)
                                Text(targetSummary(exercise))
                                    .font(.subheadline.monospacedDigit()).foregroundStyle(AppTheme.contentSecondary)
                                if draft.definition(for: exercise) == nil {
                                    Text("Match or keep as custom").font(.caption).foregroundStyle(AppTheme.contentSecondary)
                                }
                                if let notes = exercise.notes { Text(notes).font(.caption) }
                            }
                        }
                        .accessibilityIdentifier("import-exercise-\(exerciseIndex)")
                        issueRows(prefix: "/workouts/\(index)/exercises/\(exerciseIndex)", includeChildren: true)
                    }
                }
                Section("Source") {
                    DisclosureGroup(mode == .json ? "Original JSON" : "Original workout text") { Text(draft.originalText).font(.caption.monospaced()).textSelection(.enabled) }
                    Button("Edit source or choose another workout") { draft.selectedWorkoutID = nil; persist() }
                }
                Section {
                    statusMessage
                    if let error = validationMessage { Text(error).font(.footnote).foregroundStyle(AppTheme.contentSecondary) }
                    Button("Add to Today") {
                        if model.todayPlan != nil { confirmReplace = true }
                        else { Task { await savePlan() } }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(validationMessage != nil || isSaving || storageFailed)
                    .accessibilityIdentifier("import-add-to-today")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .disabled(isSaving)
    }

    @ViewBuilder private var statusMessage: some View {
        if let message { Text(message).font(.footnote).foregroundStyle(.red).accessibilityIdentifier("import-message") }
    }

    private func targetSummary(_ exercise: ImportedExercise) -> String {
        let targets = exercise.sets.map { set in
            (try? set.plannedSet().prescription.summaryText) ?? "Needs correction"
        }
        let count = "\(targets.count) \(targets.count == 1 ? "set" : "sets")"
        if Set(targets).count == 1, let target = targets.first { return count + " · " + target }
        return count + " · " + targets.joined(separator: " / ")
    }

    private var validationMessage: String? {
        do { _ = try draft.makePlan(); return nil }
        catch { return error.localizedDescription }
    }

    @ViewBuilder private func issueRows(prefix: String, includeChildren: Bool) -> some View {
        let matches: (String) -> Bool = { path in
            path == prefix || (includeChildren && path.hasPrefix(prefix + "/"))
                || (!includeChildren && !path.hasPrefix("/workouts/"))
        }
        ForEach(draft.relevantIssues().filter { matches($0.path) }) { issue in
            VStack(alignment: .leading, spacing: 6) {
                Text(issue.message).font(.subheadline.weight(.medium))
                if let quote = issue.sourceQuote { Text("Source: \(quote)").font(.caption) }
                if issue.blocking {
                    Text("Edit the source with explicit confirmed values, then convert again or ask your coach for a definite JSON file.")
                        .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                }
            }
        }
        ForEach(Array((draft.response?.confidence ?? []).enumerated()).filter { $0.element.level != "high" && matches($0.element.path) }, id: \.offset) { _, item in
            VStack(alignment: .leading) {
                Text(item.sourceQuote ?? "An uncertain source detail needs your review.").font(.caption)
                Text("An explicit confirmed interpretation is required.").font(.caption)
            }
        }
    }

    private func exerciseBinding(workout: Int, exercise: Int) -> Binding<ImportedExercise> {
        Binding(get: { draft.response!.workouts[workout].exercises[exercise] }, set: {
            draft.response?.workouts[workout].exercises[exercise] = $0; persist()
        })
    }

    private func setSource(_ text: String, kind: ImportSourceKind) {
        draft.originalText = text
        draft.sourceKind = kind
        if kind == .workoutPlanFile { draft.inputMode = .json }
        draft.sourceURL = nil
        draft.sharedPayloadID = nil
        draft.response = nil; draft.selectedWorkoutID = nil
        draft.exerciseMappings = [:]; draft.resolvedIssueIDs = []; draft.manuallyNamedTitles = nil
        message = nil
        persist()
    }

    @ViewBuilder private var sharedNotice: some View {
        if sharedWaiting {
            Text("A shared workout is waiting. Your current import draft has been kept.")
                .font(.subheadline).foregroundStyle(AppTheme.contentSecondary)
            Button("Open waiting shared workout") { confirmShared = true }
                .frame(minHeight: 44)
        } else if draft.sourceKind == .shareSheet {
            Text(draft.selectedIndex == nil ? "Shared workout saved offline. Review JSON to check its targets before adding it to Today." : "From a shared workout · saved on this iPhone")
                .font(.subheadline).foregroundStyle(AppTheme.contentSecondary)
            if !draft.originalText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
                Text("Choose Workout text to convert this source with your configured service, or use Format help to get standard JSON from your coach.")
                    .font(.footnote).foregroundStyle(AppTheme.contentSecondary)
            }
        }
    }

    private func loadSharedDraft() throws {
        guard let store else { return }
        let inbox = try AppSharedWorkoutInbox.open()
        if let received = try store.receiveSharedWorkout(from: inbox) { draft = received }
        sharedWaiting = try inbox.peek() != nil
    }

    private func persist() {
        guard !storageFailed else { return }
        guard let store else { storageFailed = true; message = "Local draft storage is unavailable."; return }
        do { try store.save(draft) }
        catch { storageFailed = true; message = "The import draft could not be saved locally. Your existing workout is unchanged." }
    }

    private var mode: WorkoutImportInputMode { draft.inputMode ?? .json }

    private func textInterpreter() throws -> WorkoutTextInterpreter {
        let environment = ProcessInfo.processInfo.environment
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
           let fixture = environment["ASCEND_FIT_UI_TEST_INTERPRETATION"] {
            let config = try WorkoutTextServiceConfiguration(baseURL: URL(string: "https://import.invalid")!, accessToken: "test-only")
            return WorkoutTextInterpreter(configuration: config) { request in
                if environment["ASCEND_FIT_UI_TEST_CONVERSION_DELAY"] != nil { try await Task.sleep(for: .seconds(5)) }
                let input = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
                var output = try JSONSerialization.jsonObject(with: Data(fixture.utf8)) as! [String: Any]
                output["source"] = ["kind": input["sourceKind"]!, "originalText": input["text"]!, "sourceURL": input["sourceURL"]!]
                let data = try JSONSerialization.data(withJSONObject: output)
                return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            throw WorkoutImportError.invalid("Text conversion is not available in this test build. JSON import works offline.")
        }
        return WorkoutTextInterpreter(configuration: try .current())
    }

    private func parse(asText: Bool = false) {
        guard !isParsing else { return }
        isEditingSource = false
        message = nil; isParsing = true
        let source = draft.originalText
        let kind = draft.sourceKind
        let sourceURL = draft.sourceURL
        let interpreter: WorkoutTextInterpreter?
        do { interpreter = asText ? try textInterpreter() : nil }
        catch { message = error.localizedDescription; isParsing = false; return }
        importTask = Task {
            do {
                let response: WorkoutImportResponse
                if let interpreter { response = try await interpreter.interpret(text: source, kind: kind, sourceURL: sourceURL) }
                else { response = try await Task.detached { try WorkoutJSONImporter.decode(source) }.value }
                guard !Task.isCancelled else { return }
                if interpreter == nil, let normalized = response.source?.originalText {
                    draft.originalText = normalized
                }
                draft.response = response
                draft.manuallyNamedTitles = nil
                draft.selectedWorkoutID = response.classification == "single" ? response.workouts.first?.id : nil
                if response.classification == "none" { message = "No workout was found. Check your source or ask your coach for one complete workout." }
                if response.classification == "multiple" { message = "Choose the workout you want to review. Nothing has been added to Today." }
                persist()
            } catch { if !Task.isCancelled { message = error.localizedDescription } }
            if !Task.isCancelled { isParsing = false }
        }
    }

    private func savePlan() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let plan = try draft.makePlan()
            if await model.schedule(plan) {
                do {
                    try store?.discardPending()
                    dismiss()
                } catch {
                    message = "The workout is saved on Today. This temporary draft could not be cleared; close import to start your workout."
                    draft.selectedWorkoutID = nil
                    draft.response = nil
                    draft.originalText = ""
                }
            } else { message = model.errorMessage }
        } catch { message = error.localizedDescription }
    }
}
