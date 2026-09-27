import SwiftUI
import UserNotifications
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var model: AppModel
    @AppStorage("preferences.appearance") private var appearance = AppAppearance.system
    @AppStorage("preferences.gymAppearance") private var gymAppearance = AppAppearance.dark
    @AppStorage("preferences.restNotificationsEnabled") private var restNotificationsEnabled = true
    @State private var canRequestNotificationPermission = false
    @State private var notificationStatus = "Checking permission…"
    @State private var confirmsDeletion = false
    @State private var isDeleting = false
    @State private var dataMessage: String?
    @State private var isUpdatingNotifications = false
    @State private var isEditingProfile = false
    @AppStorage("trainingProfile.massUnit") private var unit = MassUnit.pounds
    @AppStorage("trainingProfile.sex") private var sex = TrainingSex.preferNotToSay.rawValue
    @AppStorage("trainingProfile.heightCentimeters") private var height = 0.0
    @AppStorage("trainingProfile.bodyWeightKilograms") private var bodyWeight = 0.0
    @AppStorage("trainingProfile.experience") private var experience = TrainingExperience.beginner.rawValue

    private var profile: TrainingProfile? {
        guard height > 0, bodyWeight > 0 else { return nil }
        return TrainingProfile(
            sex: TrainingSex(rawValue: sex) ?? .preferNotToSay,
            heightCentimeters: height,
            bodyWeightKilograms: bodyWeight,
            experience: TrainingExperience(rawValue: experience) ?? .beginner
        )
    }

    var body: some View {
        List {
            Section {
                Picker("Preferred units", selection: $unit) {
                    Text("lb / in").tag(MassUnit.pounds)
                    Text("kg / cm").tag(MassUnit.kilograms)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings-units")
            } header: {
                Text("Units")
            } footer: {
                Text("Used for new manual workouts and profile measurements. Saved workouts and history keep their recorded units.")
            }
            .listRowBackground(AppTheme.surfacePrimary)

            Section {
                Button {
                    isEditingProfile = true
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Training profile")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.contentPrimary)
                            if let profile {
                                Text(profile.experience.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.contentSecondary)
                            } else {
                                Text("Add your measurements and lifting experience")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.contentSecondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.contentTertiary)
                    }
                    .frame(minHeight: 60)
                }
                .accessibilityIdentifier("settings-training-profile")
            } footer: {
                Text("Your profile helps estimate editable starting weights. Updating it affects future suggestions.")
            }
            .listRowBackground(AppTheme.surfacePrimary)

            Section("Appearance") {
                Picker("Planning and history", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("settings-appearance")
                Picker("During workouts", selection: $gymAppearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("settings-gym-appearance")
            }
            .listRowBackground(AppTheme.surfacePrimary)

            Section {
                Toggle("Rest notifications", isOn: Binding(
                    get: { restNotificationsEnabled },
                    set: { enabled in
                        restNotificationsEnabled = enabled
                        isUpdatingNotifications = true
                        Task {
                            await model.updateRestNotificationPreference(enabled: enabled)
                            await refreshNotificationStatus()
                            isUpdatingNotifications = false
                        }
                    }
                ))
                .disabled(isUpdatingNotifications)
                .accessibilityIdentifier("settings-rest-notifications")
                LabeledContent("iPhone permission", value: notificationStatus)
                    .font(.subheadline)
                    .accessibilityIdentifier("settings-notification-status")
                if restNotificationsEnabled && canRequestNotificationPermission {
                    Button("Allow rest notifications") {
                        isUpdatingNotifications = true
                        Task {
                            if !ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                                do {
                                    _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
                                } catch {
                                    dataMessage = "Notification permission could not be requested. You can change it in iPhone Settings."
                                }
                            }
                            await model.updateRestNotificationPreference(enabled: true)
                            await refreshNotificationStatus()
                            isUpdatingNotifications = false
                        }
                    }
                    .disabled(isUpdatingNotifications)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("settings-request-notifications")
                }
                Button("Open iPhone notification settings") {
                    guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
                    openURL(url)
                }
                .frame(minHeight: 44)
            } header: {
                Text("Workout rest")
            } footer: {
                Text("Notifications can alert you when rest ends while the app is in the background. The timer still works when notifications are off. Set rest durations in the builder or while training.")
            }
            .listRowBackground(AppTheme.surfacePrimary)

            Section {
                Text("Your workouts and training profile are stored locally on this iPhone. This build has no account, cloud sync, or AI workout upload. Device backups may include app data, depending on your iPhone backup settings.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.contentSecondary)
                Menu {
                    WorkoutExportActions(entries: model.workoutHistory)
                } label: {
                    Label("Export workout history", systemImage: "square.and.arrow.up")
                        .frame(minHeight: 44)
                }
                .disabled(model.workoutHistory.isEmpty || model.isRestoring || isDeleting)
                .accessibilityIdentifier("settings-export-history")
                Button(role: .destructive) {
                    confirmsDeletion = true
                } label: {
                    Label(isDeleting ? "Deleting workouts…" : "Delete local workout data", systemImage: "trash")
                        .frame(minHeight: 44)
                }
                .disabled(model.isRestoring || isDeleting || hasUnfinishedWorkout)
                .accessibilityIdentifier("settings-delete-workout-data")
                if hasUnfinishedWorkout {
                    Text("Finish or discard your active workout before deleting workout data.")
                        .font(.footnote)
                }
                if let dataMessage {
                    Text(dataMessage)
                        .font(.footnote)
                        .accessibilityIdentifier("settings-data-message")
                }
            } header: {
                Text("Your data")
            } footer: {
                Text("Export shares completed workouts as JSON or CSV with a destination you choose. Deletion removes saved plans and workout history from this app. Your training profile and preferences remain. Copies you exported are not deleted.")
            }
            .listRowBackground(AppTheme.surfacePrimary)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .tint(AppTheme.accentContent)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(AppTheme.accentContent)
            }
        }
        .task { await refreshNotificationStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refreshNotificationStatus() } }
        }
        .confirmationDialog("Delete all local workout data?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Delete all workouts", role: .destructive) {
                isDeleting = true
                Task {
                    let deleted = await model.deleteAllWorkoutData()
                    dataMessage = deleted ? "All local workout plans and history were deleted." : (model.errorMessage ?? "Your workouts could not be deleted. Please try again.")
                    isDeleting = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes saved workout plans, sessions, history, pending imports, and retained source text from this app. Your training profile and preferences remain. Export any history you want to keep first.")
        }
        .sheet(isPresented: $isEditingProfile) {
            TrainingProfileEditor(unit: unit, profile: profile) { updated in
                sex = updated.sex.rawValue
                height = updated.heightCentimeters
                bodyWeight = updated.bodyWeightKilograms
                experience = updated.experience.rawValue
            }
        }
    }

    private var hasUnfinishedWorkout: Bool {
        guard let session = model.activeSession else { return false }
        switch session.status {
        case .completed, .discarded: return false
        default: return true
        }
    }

    private func refreshNotificationStatus() async {
        let status: Int = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus.rawValue)
            }
        }
        canRequestNotificationPermission = status == UNAuthorizationStatus.notDetermined.rawValue
        switch status {
        case UNAuthorizationStatus.notDetermined.rawValue: notificationStatus = "Not requested"
        case UNAuthorizationStatus.denied.rawValue: notificationStatus = "Off in Settings"
        case UNAuthorizationStatus.authorized.rawValue: notificationStatus = "Allowed"
        case UNAuthorizationStatus.provisional.rawValue: notificationStatus = "Quiet delivery"
        case UNAuthorizationStatus.ephemeral.rawValue: notificationStatus = "Temporary permission"
        default: notificationStatus = "Unavailable"
        }
    }

}
