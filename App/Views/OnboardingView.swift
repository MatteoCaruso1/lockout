import FamilyControls
import LockoutCore
import SwiftUI
import UIKit

/// Authorize → keep Lockout usable → Messages → Downtime → sealed passcode →
/// 2-minute test lock. Each step is saved, so quitting halfway resumes there.
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var welcomeSeen = false
    @State private var showPicker = false
    @State private var selection = FamilyActivitySelection()
    @State private var skippedRecovery = false
    @State private var armRequest: ArmRequest?
    @State private var testFailed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(24)
            }
            .navigationTitle("Set up Lockout")
            .sheet(item: $armRequest) { request in
                ArmView(request: request)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let o = model.state.onboarding
        if !welcomeSeen && !o.authorized && model.state.lastAuthorizedAt == nil {
            welcome
        } else if !o.authorized {
            authorize
        } else if !o.exemptionPicked {
            exemption
        } else if !o.messagesRemoved {
            messages
        } else if !o.downtimeStepSeen {
            downtime
        } else if !o.passcodeSealed {
            passcode
        } else {
            testLock
        }
    }

    // MARK: Steps

    private var welcome: some View {
        Group {
            Text("Lockout").font(.largeTitle.bold())
            Text("When you start a lock, every app and website is blocked until the time is up. No one can end it early, including you. Phone and emergency calls always work.")
            Text("Setup takes about 5 minutes and ends with a 2-minute test lock.")
                .foregroundStyle(.secondary)
            primary("Start setup") { welcomeSeen = true }
        }
    }

    private var authorize: some View {
        Group {
            stepTitle(1, "Allow Screen Time access")
            Text("Lockout uses Apple's Screen Time to block apps. iOS will ask you to confirm with Face ID or your passcode.")
            if model.state.lastAuthorizedAt != nil {
                Text("Screen Time access was switched off in Settings. Lockout logged when it noticed (see History).")
                    .foregroundStyle(.orange)
            }
            primary("Allow access") { Task { await model.requestAuthorization() } }
        }
    }

    private var exemption: some View {
        Group {
            stepTitle(2, "Keep Lockout itself usable")
            Text("So you can see the countdown during a lock, pick **Lockout** in the next list (and only Lockout). Use the search box at the top.")
            primary("Choose Lockout") { showPicker = true }
            Button("Skip (the lock works, but Lockout will be blocked too)") { model.setOnboarding(\.exemptionPicked) }
                .font(.footnote)
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: selection) { newValue in
            guard !newValue.applicationTokens.isEmpty else { return }
            model.saveExemption(newValue)
        }
    }

    private var messages: some View {
        Group {
            stepTitle(3, "Let Lockout block Messages")
            Text("iOS lets Messages through by default. Remove it:")
            numbered([
                "Open **Settings → Screen Time → Always Allowed**.",
                "Tap the red minus next to **Messages**, then **Remove**.",
                "Come back here.",
            ])
            openSettingsButton
            primary("I removed Messages") { model.setOnboarding(\.messagesRemoved) }
        }
    }

    private var downtime: some View {
        Group {
            stepTitle(4, "Back-up layer: iOS Downtime")
            Text("One gap Apple leaves open: switching off Lockout's Screen Time access in Settings ends a lock. iOS's own Downtime is protected by the passcode you'll seal in the next step, so copying your usual nightly window into it means that window holds even then.")
            numbered([
                "Open **Settings → Screen Time → Downtime**.",
                "Turn on **Scheduled** and set the days and times of your usual nightly lock.",
                "Come back here. You will switch on **Block at Downtime** in the next step.",
            ])
            openSettingsButton
            primary("Done") { model.setOnboarding(\.downtimeStepSeen) }
            Button("Skip for now") { model.setOnboarding(\.downtimeStepSeen) }.font(.footnote)
        }
    }

    private var passcode: some View {
        Group {
            stepTitle(5, "Seal your Screen Time passcode")
            Text("Lockout made a passcode for you. Set it now; after this screen Lockout keeps it hidden, and only shows it 24 hours after you ask, never during a lock. Try not to memorise it.")
            if let code = model.state.passcode?.code {
                Text(code)
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            numbered([
                "Open **Settings → Screen Time → Lock Screen Time Settings** (or **Change Screen Time Passcode** if you already have one) and enter the code above twice.",
                "When iOS asks for your Apple ID for passcode recovery, tap **Cancel**. Otherwise your Apple ID password could reset it at any time.",
                "If you set up Downtime: open **Downtime** and switch on **Block at Downtime** (enter the code when asked).",
            ])
            openSettingsButton
            Toggle("I tapped Cancel at the Apple ID recovery screen", isOn: $skippedRecovery)
            primary("Seal it") { model.setOnboarding(\.passcodeSealed) }
                .disabled(!skippedRecovery)
        }
        .onAppear { model.preparePasscode() }
    }

    @ViewBuilder
    private var testLock: some View {
        stepTitle(6, "Prove it works: 2-minute test lock")
        if model.state.onboarding.testLockStartedAt == nil || testFailed {
            Text("Start a real 2-minute lock. While it runs, try opening a few apps, Safari and Messages. They should all show the Lockout screen. It ends by itself.")
            if testFailed {
                Text("Check that Messages is removed from Always Allowed and that Lockout still has Screen Time access, then run the test again.")
                    .foregroundStyle(.orange)
            }
            primary("Start 2-minute test lock") {
                testFailed = false
                model.resetTestLock()
                armRequest = ArmRequest(duration: Limits.testLockDuration, source: .test)
            }
        } else {
            Text("The test lock has ended. Were apps, Safari and Messages blocked while it ran?")
            primary("Yes, everything was blocked") { model.setOnboarding(\.testLockPassed) }
            Button("Something was not blocked") { testFailed = true }
        }
    }

    // MARK: Building blocks

    private func stepTitle(_ number: Int, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Step \(number) of 6").font(.caption).foregroundStyle(.secondary)
            Text(title).font(.title2.bold())
        }
    }

    private func numbered(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1).").bold()
                    Text(.init(line))
                }
            }
        }
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var openSettingsButton: some View {
        Button("Open Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        }
    }
}
