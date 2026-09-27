import UIKit
import SwiftUI
import UniformTypeIdentifiers

@objc(ShareViewController)
@MainActor
final class ShareViewController: UIViewController {
    private var captureTask: Task<Void, Never>?
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        let model = ShareCaptureModel()
        model.close = { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) }
        let host = UIHostingController(rootView: ShareCaptureView(model: model))
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        captureTask = Task {
            var texts: [String] = []
            var sourceURL: URL?
            do {
                for item in items {
                    var attachedText = false
                    for provider in item.attachments ?? [] {
                        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                            let data: Data = try await withCheckedThrowingContinuation { continuation in
                                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { value, error in
                                    if let error { continuation.resume(throwing: error); return }
                                    guard let url = value as? URL, url.pathExtension.lowercased() == "json" else { continuation.resume(throwing: ShareCaptureError.unsupported); return }
                                    let scoped = url.startAccessingSecurityScopedResource()
                                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                                    do {
                                        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                                        guard size <= SharedWorkoutInbox.maximumBytes else { throw SharedWorkoutInboxError.oversized }
                                        let handle = try FileHandle(forReadingFrom: url)
                                        defer { try? handle.close() }
                                        let data = try handle.read(upToCount: SharedWorkoutInbox.maximumBytes + 1) ?? Data()
                                        guard data.count <= SharedWorkoutInbox.maximumBytes else { throw SharedWorkoutInboxError.oversized }
                                        continuation.resume(returning: data)
                                    } catch { continuation.resume(throwing: error) }
                                }
                            }
                            guard let text = String(data: data, encoding: .utf8) else { throw ShareCaptureError.unsupported }
                            texts.append(text); attachedText = true
                        } else if provider.hasItemConformingToTypeIdentifier(UTType.json.identifier) {
                            if let data = try await loadData(provider, type: UTType.json.identifier) {
                                guard data.count <= SharedWorkoutInbox.maximumBytes else { throw SharedWorkoutInboxError.oversized }
                                guard let text = String(data: data, encoding: .utf8) else { throw ShareCaptureError.unsupported }
                                texts.append(text); attachedText = true
                            }
                        } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                            let urlText: String? = try await withCheckedThrowingContinuation { continuation in
                                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { value, error in
                                    if let error { continuation.resume(throwing: error) }
                                    else { continuation.resume(returning: (value as? URL)?.absoluteString ?? (value as? String)) }
                                }
                            }
                            if let urlText { sourceURL = URL(string: urlText) }
                        } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                            if let data = try await loadData(provider, type: UTType.plainText.identifier), let text = String(data: data, encoding: .utf8) {
                                guard data.count <= SharedWorkoutInbox.maximumBytes else { throw SharedWorkoutInboxError.oversized }
                                texts.append(text); attachedText = true
                            }
                        } else if provider.hasItemConformingToTypeIdentifier(UTType.rtf.identifier) {
                            if let data = try await loadData(provider, type: UTType.rtf.identifier) {
                                guard data.count <= SharedWorkoutInbox.maximumBytes else { throw SharedWorkoutInboxError.oversized }
                                texts.append(try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil).string)
                                attachedText = true
                            }
                        }
                    }
                    if !attachedText, let text = item.attributedContentText?.string { texts.append(text) }
                }
                guard !Task.isCancelled else { return }
                let uniqueTexts = Array(Set(texts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }))
                guard uniqueTexts.count <= 1 else { throw ShareCaptureError.unsupported }
                let text = uniqueTexts.first ?? ""
                guard text.utf8.count <= SharedWorkoutInbox.maximumBytes else { throw SharedWorkoutInboxError.oversized }
                // Some hosts expose a link as plain text. It cannot supply the actual workout.
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if let url = URL(string: trimmed), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), !trimmed.contains(where: { $0.isWhitespace }) {
                    model.sourceURL = sourceURL ?? url; model.text = ""
                } else { model.sourceURL = sourceURL; model.text = text }
                model.loading = false
            } catch {
                model.loading = false
                model.error = error is SharedWorkoutInboxError ? error.localizedDescription : "This item could not be read. Copy the workout text or share its JSON file, then try again."
            }
        }
    }
    private func loadData(_ provider: NSItemProvider, type: String) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: data) }
            }
        }
    }
    deinit { captureTask?.cancel() }
}

private enum ShareCaptureError: Error { case unsupported }

@Observable @MainActor
private final class ShareCaptureModel {
    var text = ""
    var sourceURL: URL?
    var loading = true
    var saved = false
    var error: String?
    var close: (() -> Void)?
    func save() {
        do {
            let inbox = SharedWorkoutInbox(directory: try SharedWorkoutInbox.defaultDirectory())
            _ = try inbox.enqueue(text: text, sourceURL: sourceURL)
            saved = true; error = nil
        } catch { self.error = error.localizedDescription }
    }
}

private struct ShareCaptureView: View {
    @Bindable var model: ShareCaptureModel
    private let accent = Color(red: 183 / 255, green: 164 / 255, blue: 1)
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: model.saved ? "checkmark.circle" : "square.and.arrow.down").font(.largeTitle).foregroundStyle(accent)
                    Text(model.saved ? "Saved for review" : "Bring your workout").font(.largeTitle.bold())
                    if model.loading { ProgressView("Reading shared item…") }
                    else if model.saved {
                        Text("Open Ascend Fit within seven days to review and keep this workout. It stays on your iPhone and won’t replace Today until you confirm.")
                    } else if model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("A shared link may not include the workout. In your coach’s app, copy the workout JSON or text, then paste it into Ascend Fit. You can also share a JSON file.")
                        if let url = model.sourceURL { Text(url.absoluteString).font(.footnote).foregroundStyle(.secondary).textSelection(.enabled) }
                    } else {
                        Text("Save this item offline, then open Ascend Fit within seven days to review it. Nothing is added to Today automatically.")
                        Text(String(model.text.prefix(4_000))).font(.callout).textSelection(.enabled)
                        if model.text.count > 4_000 { Text("Preview shortened. The full workout will be saved for review.").font(.caption).foregroundStyle(.secondary) }
                    }
                    if let error = model.error { Text(error).foregroundStyle(.red).accessibilityIdentifier("shareCaptureError") }
                }.foregroundStyle(Color(red: 240 / 255, green: 238 / 255, blue: 245 / 255))
                .frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }
            .background(Color(red: 11 / 255, green: 11 / 255, blue: 15 / 255))
            .safeAreaInset(edge: .bottom) {
                VStack {
                    if model.saved {
                        Button("Done") { model.close?() }.buttonStyle(.borderedProminent).foregroundStyle(Color(red: 20 / 255, green: 15 / 255, blue: 42 / 255))
                    } else {
                        Button("Save for review") { model.save() }.buttonStyle(.borderedProminent).foregroundStyle(Color(red: 20 / 255, green: 15 / 255, blue: 42 / 255))
                            .disabled(model.loading || model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("shareSaveForReview")
                    }
                }.controlSize(.large).frame(maxWidth: .infinity).padding().background(Color(red: 20 / 255, green: 18 / 255, blue: 26 / 255))
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(model.saved ? "Close" : "Cancel") { model.close?() } } }
        }.tint(accent).preferredColorScheme(.dark)
    }
}
