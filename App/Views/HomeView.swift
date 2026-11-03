import LockoutCore
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var armRequest: ArmRequest?
    @State private var showCustom = false

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 12)]

    var body: some View {
        NavigationStack {
            List {
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

                Section {
                    NavigationLink("Screen Time passcode") { PasscodeView() }
                    NavigationLink("History") { HistoryView() }
                }
            }
            .navigationTitle("Lockout")
            .sheet(item: $armRequest) { request in
                ArmView(request: request)
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
