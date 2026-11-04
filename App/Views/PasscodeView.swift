import LockoutCore
import SwiftUI

/// The sealed Screen Time passcode: asked for, then shown 24 hours later, and
/// never while a lock is running.
struct PasscodeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmRequest = false

    var body: some View {
        List {
            if let passcode = model.state.passcode, model.state.onboarding.passcodeSealed {
                if model.state.canRevealPasscode(model.current) {
                    Section("Your Screen Time passcode") {
                        Text(passcode.code)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity)
                        Button("Seal it again") { model.resealPasscode() }
                    }
                } else if let requested = passcode.revealRequestedAt {
                    Section {
                        Text("You asked for it \(Format.dateTime(requested)). It can be shown from \(Format.dateTime(requested.addingTimeInterval(Limits.passcodeRevealDelay))), as long as no lock is running then.")
                    }
                } else {
                    Section {
                        Text("Lockout keeps your Screen Time passcode out of sight so you can't switch Screen Time off on a whim.")
                        Button("Ask to see it (24-hour wait)") { confirmRequest = true }
                    }
                }
            } else {
                Section {
                    Text("No sealed passcode yet. Turn on Strict mode from the home screen to set one.")
                }
            }
        }
        .navigationTitle("Passcode")
        .confirmationDialog("The passcode will be viewable 24 hours from now, if no lock is running at that moment.",
                            isPresented: $confirmRequest, titleVisibility: .visible) {
            Button("Start the 24-hour wait") { model.requestPasscodeReveal() }
        }
    }
}
