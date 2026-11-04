import LockoutCore
import SwiftUI

/// v0.2 setup, three screens: allow access → Always Allowed (optional) →
/// try it or start. Strict mode (sealed passcode, Downtime) is offered later
/// from Home, not here. `replay` shows the same screens from Home without
/// changing anything that is already set up.
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var replay = false

    @State private var page = 0
    @State private var armRequest: ArmRequest?
    @State private var asking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    progress
                    switch page {
                    case 0: allowAccess
                    case 1: alwaysAllowed
                    default: ready
                    }
                }
                .padding(24)
            }
            .toolbar {
                if replay {
                    ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                }
            }
            .sheet(item: $armRequest) { request in
                ArmView(request: request)
            }
        }
        .onAppear {
            // Resume where a first-time setup stopped. Lost access always
            // comes back to the first screen.
            if !replay && model.state.onboarding.authorized { page = 1 }
        }
        .onChange(of: model.state.onboarding.authorized) { authorized in
            if !authorized { page = 0 }
        }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(i <= page ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(height: 4)
            }
        }
    }

    // MARK: Screens

    private var allowAccess: some View {
        Group {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
            Text("Lockout").font(.largeTitle.bold()).frame(maxWidth: .infinity)
            Text("Pick a length, and every app and website is blocked until the time is up. No one can end it early, including you. Phone and emergency calls always work.")
            if model.state.lastAuthorizedAt != nil && !model.state.onboarding.authorized {
                Text("Screen Time access for Lockout was switched off in Settings. Allow it again to keep using Lockout. (History shows when this happened.)")
                    .foregroundStyle(.orange)
            }
            Text("Lockout uses Apple's Screen Time to block apps. iOS will ask you to confirm with Face ID. Nothing leaves your phone.")
                .foregroundStyle(.secondary)
            primary(asking ? "Waiting for iOS…" : "Allow Screen Time access") {
                asking = true
                Task {
                    await model.requestAuthorization()
                    asking = false
                    if model.state.onboarding.authorized { page = 1 }
                }
            }
            .disabled(asking)
        }
    }

    private var alwaysAllowed: some View {
        Group {
            AlwaysAllowedSteps()
            primary("Done, only Phone is left") {
                model.setOnboarding(\.messagesRemoved)
                page = 2
            }
            Button("Keep Messages and Maps open for now") { page = 2 }
                .frame(maxWidth: .infinity)
        }
    }

    private var ready: some View {
        Group {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
            Text("You're set").font(.largeTitle.bold()).frame(maxWidth: .infinity)
            Text("Start a lock from the home screen whenever you need it, or add a schedule such as every night from 10 PM to 7 AM.")
            Text("Want to see it work first? A 2-minute lock blocks everything, then ends by itself.")
                .foregroundStyle(.secondary)
            // Setup is marked finished when the test lock actually starts
            // (AppModel.arm), so cancelling it comes back here.
            primary("Try a 2-minute lock") {
                model.prepareTestLock()
                armRequest = ArmRequest(duration: Limits.testLockDuration, source: .test)
            }
            Button("Start using Lockout") {
                finish()
                if replay { dismiss() }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func finish() {
        model.setOnboarding(\.setupFinished)
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}
