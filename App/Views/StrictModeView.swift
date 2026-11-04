import LockoutCore
import SwiftUI
import UIKit

/// Optional hardening, moved out of setup in v0.2: a Screen Time passcode
/// that Lockout keeps sealed (so Screen Time can't be switched off on a whim)
/// and iOS Downtime as a back-up for the nightly window.
struct StrictModeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var skippedRecovery = false
    @State private var confirmSeal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if model.state.onboarding.passcodeSealed {
                    sealed
                } else {
                    setup
                }
            }
            .padding(24)
        }
        .navigationTitle("Strict mode")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sealed: some View {
        Group {
            Label("Strict mode is on", systemImage: "checkmark.seal.fill")
                .font(.title2.bold())
                .foregroundStyle(.green)
            Text("Your Screen Time passcode is sealed. Lockout shows it 24 hours after you ask, and never during a lock.")
            NavigationLink("Screen Time passcode") { PasscodeView() }
        }
    }

    private var setup: some View {
        Group {
            Text("Make it really hard to cheat")
                .font(.title2.bold())
            Text("A lock already can't be ended from Lockout. But anyone who knows the phone's Screen Time settings can switch Screen Time off. Strict mode locks those settings with a passcode that Lockout keeps hidden from you.")
            Text("Trade-off: if you ever lose this passcode, the only way to reset it is to erase the iPhone. Lockout shows it again 24 hours after you ask.")
                .font(.footnote)
                .foregroundStyle(.orange)

            Text("Your passcode").font(.headline)
            if let code = model.state.passcode?.code {
                Text(code)
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity)
            }

            step(1, "In Settings → Screen Time, tap **Lock Screen Time Settings** (or **Change Screen Time Passcode**) and enter the code above twice.")
            SettingsMock.screenTimePasscode
            step(2, "iOS then asks for your Apple ID for passcode recovery. Tap **Cancel**. Otherwise your Apple ID password could reset the passcode at any time.")
            step(3, "Optional back-up for your nightly lock: in **Downtime**, turn on **Scheduled** with your nightly hours and **Block at Downtime**. iOS keeps that one even if Lockout's Screen Time access is switched off.")
            SettingsMock.downtime
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            } label: {
                Label("Open Settings", systemImage: "gear")
            }

            Toggle("I entered the code and tapped Cancel at the Apple ID screen", isOn: $skippedRecovery)
            Button {
                confirmSeal = true
            } label: {
                Text("Seal the passcode").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!skippedRecovery)
        }
        .onAppear { model.preparePasscode() }
        .confirmationDialog("After this, the passcode is hidden. You can ask to see it, and it's shown 24 hours later.",
                            isPresented: $confirmSeal, titleVisibility: .visible) {
            Button("Seal it") {
                model.setOnboarding(\.downtimeStepSeen)
                model.setOnboarding(\.passcodeSealed)
            }
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(n)").bold().frame(width: 22, height: 22).background(Circle().fill(Color.accentColor.opacity(0.3)))
            Text(LocalizedStringKey(text))
        }
    }
}
