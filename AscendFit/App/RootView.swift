import SwiftUI

struct RootView: View {
    @StateObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("preferences.appearance") private var appearance = AppAppearance.dark
    @AppStorage("preferences.gymAppearance") private var gymAppearance = AppAppearance.dark

    @AppStorage("trainingProfile.completed") private var hasCompletedTrainingProfile = false
    @AppStorage("trainingProfile.massUnit") private var massUnit = MassUnit.pounds
    @AppStorage("trainingProfile.sex") private var profileSex = TrainingSex.preferNotToSay.rawValue
    @AppStorage("trainingProfile.heightCentimeters") private var profileHeightCentimeters = 0.0
    @AppStorage("trainingProfile.bodyWeightKilograms") private var profileBodyWeightKilograms = 0.0
    @AppStorage("trainingProfile.experience") private var profileExperience = TrainingExperience.beginner.rawValue

    init(preferenceStore: UserDefaults = .standard) {
        _model = StateObject(wrappedValue: AppModel(preferenceStore: preferenceStore))
    }

    var body: some View {
        Group {
            if shouldShowOnboarding {
                OnboardingView(onComplete: saveTrainingProfile)
            } else {
                appTabs
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.reconcileRestNotificationOnActivation() }
            }
        }
    }

    private var shouldShowOnboarding: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing-onboarding") { return true }
        if arguments.contains("--ui-testing") { return false }
        return !hasCompletedTrainingProfile
    }

    private var appTabs: some View {
        TabView {
            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: "calendar") }

            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "clock") }
        }
        .tint(AppTheme.accentContent)
        .environmentObject(model)
        .fullScreenCover(item: $model.activeSession) { _ in
            ActiveWorkoutView()
                .environmentObject(model)
                .preferredColorScheme(gymAppearance.colorScheme)
        }
    }

    private func saveTrainingProfile(_ profile: TrainingProfile, unit: MassUnit) {
        massUnit = unit
        profileSex = profile.sex.rawValue
        profileHeightCentimeters = profile.heightCentimeters
        profileBodyWeightKilograms = profile.bodyWeightKilograms
        profileExperience = profile.experience.rawValue
        hasCompletedTrainingProfile = true
    }
}
