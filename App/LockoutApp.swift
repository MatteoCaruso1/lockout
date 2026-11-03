import SwiftUI

@main
struct LockoutApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { model.becameActive() }
        }
    }
}

/// A running lock always wins: while locked, the only screen is the countdown.
struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.isLocked {
                CountdownView()
            } else if !model.state.onboarding.isComplete {
                OnboardingView()
            } else {
                HomeView()
            }
        }
        .alert("Can't do that", isPresented: Binding(get: { model.errorMessage != nil },
                                                     set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .alert("Lockout", isPresented: Binding(get: { model.notice != nil },
                                               set: { if !$0 { model.notice = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.notice ?? "")
        }
    }
}
