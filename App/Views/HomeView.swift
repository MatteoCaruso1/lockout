import LockoutCore
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var armRequest: ArmRequest?
    @State private var showCustom = false
    @State private var showSetup = false

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 12)]

    var body: some View {
        NavigationStack {
            List {
                if let started = model.state.onboarding.testLockStartedAt, !model.state.onboarding.testLockPassed {
                    Section("Your test lock") {
                        Text("Did every app you tried get blocked during the test that started \(Format.clock(started))?")
                        Button("Yes, everything was blocked") { model.setOnboarding(\.testLockPassed) }
                        // Answering here would remove this row while its
                        // screen is open and pop it, so the card stays until "Yes".
                        NavigationLink("Something still opened") { AlwaysAllowedView() }
                    }
                }

                Section("Lock me out for") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Limits.presetHours, id: \.self) { hours in
                            presetButton(Format.duration(TimeInterval(hours * 3600))) {
                                armRequest = ArmRequest(duration: TimeInterval(hours * 3600))
                            }
                        }
                        presetButton("Custom") { showCustom = true }
                    }
                    .padding(.vertical, 6)
                }

                Section("Schedules") {
                    NavigationLink {
                        SchedulesView()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.state.schedules.isEmpty ? "No schedules" : "\(model.state.schedules.count) schedule\(model.state.schedules.count == 1 ? "" : "s")")
                            if let next = model.state.nextScheduledStart(after: model.current.wall, calendar: model.calendar) {
                                Text("Next lock \(Format.dateTime(next))").font(.caption).foregroundStyle(.secondary)
                            }
                            if !model.state.pending.isEmpty {
                                Text("\(model.state.pending.count) change waiting out its 24h cooldown").font(.caption).foregroundStyle(.orange)
                            }
                        }
                    }
                }

                if model.state.onboarding.stricterStepsLeft > 0 {
                    Section {
                        if !model.state.onboarding.messagesRemoved {
                            NavigationLink { AlwaysAllowedView() } label: {
                                stricterRow("Block Messages and Maps too", "iOS lets them through until you remove them from Always Allowed.", "message.fill")
                            }
                        }
                        if !model.state.onboarding.passcodeSealed {
                            NavigationLink { StrictModeView() } label: {
                                stricterRow("Strict mode", "Stop Screen Time itself from being switched off.", "lock.shield.fill")
                            }
                        }
                    } header: {
                        Text("Make it stricter")
                    }
                }

                Section {
                    Button("Try a 2-minute lock") {
                        model.prepareTestLock()
                        armRequest = ArmRequest(duration: Limits.testLockDuration, source: .test)
                    }
                    if model.state.onboarding.passcodeSealed {
                        NavigationLink("Strict mode") { StrictModeView() }
                    }
                    NavigationLink("History") { HistoryView() }
                    Button("Replay setup") { showSetup = true }
                }
            }
            .navigationTitle("Lockout")
            .sheet(item: $armRequest) { request in
                ArmView(request: request)
            }
            .sheet(isPresented: $showSetup) {
                OnboardingView(replay: true)
            }
            .sheet(isPresented: $showCustom) {
                CustomDurationView { seconds in
                    showCustom = false
                    // Let the first sheet finish closing before opening the next.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        armRequest = ArmRequest(duration: seconds)
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func stricterRow(_ title: String, _ detail: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.orange).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func presetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.bordered)
    }
}

struct CustomDurationView: View {
    let onChoose: (TimeInterval) -> Void
    @State private var hours = 1
    @State private var minutes = 30

    private var seconds: TimeInterval { TimeInterval(hours * 3600 + minutes * 60) }
    private var valid: Bool { seconds >= Limits.minOnDemand && seconds <= Limits.maxOnDemand }

    var body: some View {
        VStack(spacing: 16) {
            Text("Custom lock").font(.headline)
            HStack {
                Picker("Hours", selection: $hours) {
                    ForEach(0...Int(Limits.maxOnDemand / 3600), id: \.self) { Text("\($0) h") }
                }
                Picker("Minutes", selection: $minutes) {
                    ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { Text("\($0) min") }
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
            Button("Continue") { onChoose(seconds) }
                .buttonStyle(.borderedProminent)
                .disabled(!valid)
            if !valid {
                Text("Between 1 minute and \(Format.duration(Limits.maxOnDemand)).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(Array(model.state.events.reversed().enumerated()), id: \.offset) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(item.element.detail)
                Text(Format.dateTime(item.element.date)).font(.caption).foregroundStyle(.secondary)
            }
            .foregroundStyle(item.element.kind == "revoked" || item.element.kind == "clock" ? Color.orange : Color.primary)
        }
        .navigationTitle("History")
        .overlay {
            if model.state.events.isEmpty { Text("Nothing yet.").foregroundStyle(.secondary) }
        }
    }
}
