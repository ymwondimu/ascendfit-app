import SwiftUI
import UIKit

struct WorkoutImportFormatHelp: View {
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Ask ChatGPT to format your workout").font(.title2.bold())
                    Text("Copy this prompt into your existing coaching chat. Resolve any missing weights, units, or alternatives with your coach, then paste the single definite workout JSON here or save it as a .json file.")
                    Button(copied ? "Prompt copied" : "Copy ChatGPT prompt") {
                        UIPasteboard.general.string = Self.prompt
                        copied = true
                    }.buttonStyle(PrimaryActionButtonStyle())
                    Text(Self.prompt).font(.caption.monospaced()).textSelection(.enabled)
                }.padding(AppTheme.Spacing.screenInset)
            }
            .navigationTitle("Workout format")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    static var prompt: String {
        guard let url = Bundle.main.url(forResource: "CHATGPT-WORKOUT-PROMPT", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "The workout format prompt could not be loaded. Reopen the app and try again."
        }
        return text
    }
}
