import LockoutCore
import SwiftUI

struct SchedulesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: EditTarget?

    struct EditTarget: Identifiable {
        let id = UUID()
        let schedule: Schedule?
    }

    var body: some View {
        List {
            Section {
                ForEach(model.state.schedules) { schedule in
                    Button {
                        editing = EditTarget(schedule: schedule)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(schedule.name).foregroundStyle(schedule.enabled ? .primary : .secondary)
                            Text(Format.schedule(schedule) + (schedule.enabled ? "" : " (off)"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("Making a schedule stricter applies immediately. Making it weaker (shorter, fewer days, off, deleted) waits 24 hours, so tonight's lock can't be cancelled at the last minute.")
            }

            if !model.state.pending.isEmpty {
                Section("Waiting out the 24h cooldown") {
                    ForEach(model.state.pending) { change in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(describe(change))
                            Text("Takes effect \(Format.dateTime(change.effectiveAt))").font(.caption).foregroundStyle(.orange)
                            Button("Cancel this change (keeps the current schedule)") { model.cancelPending(change.id) }
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle("Schedules")
        .toolbar {
            Button {
                editing = EditTarget(schedule: nil)
            } label: {
                Image(systemName: "plus")
            }
            .disabled(model.state.schedules.count >= Limits.maxSchedules)
        }
        .sheet(item: $editing) { target in
            ScheduleEditor(original: target.schedule)
        }
    }

    private func describe(_ change: PendingChange) -> String {
        let name = model.state.schedules.first { $0.id == change.scheduleID }?.name ?? "Schedule"
        guard let new = change.newValue else { return "Delete \"\(name)\"" }
        return "Change \"\(name)\" to: \(Format.schedule(new))\(new.enabled ? "" : " (off)")"
    }
}

struct ScheduleEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let original: Schedule?

    @State private var name = "Night"
    @State private var recurring = true
    @State private var weekdays: Set<Int> = Schedule.everyDay
    @State private var startTime = ScheduleEditor.time(22, 0)
    @State private var endTime = ScheduleEditor.time(7, 0)
    @State private var oneOffStart = Date().addingTimeInterval(3600)
    @State private var oneOffEnd = Date().addingTimeInterval(3 * 3600)
    @State private var enabled = true
    @State private var confirmDelete = false

    init(original: Schedule?) {
        self.original = original
        guard let original else { return }
        _name = State(initialValue: original.name)
        _enabled = State(initialValue: original.enabled)
        switch original.kind {
        case let .recurring(days, start, end):
            _recurring = State(initialValue: true)
            _weekdays = State(initialValue: days)
            _startTime = State(initialValue: Self.time(start / 60, start % 60))
            _endTime = State(initialValue: Self.time(end / 60, end % 60))
        case let .oneOff(start, end):
            _recurring = State(initialValue: false)
            _oneOffStart = State(initialValue: start)
            _oneOffEnd = State(initialValue: end)
        }
    }

    static func time(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private func minuteOfDay(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private var built: Schedule {
        let kind: Schedule.Kind = recurring
            ? .recurring(weekdays: weekdays, startMinute: minuteOfDay(startTime), endMinute: minuteOfDay(endTime))
            : .oneOff(start: oneOffStart, end: oneOffEnd)
        return Schedule(id: original?.id ?? UUID(), name: name.isEmpty ? "Lock" : name, kind: kind, enabled: enabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $recurring) {
                    Text("Repeating").tag(true)
                    Text("One time").tag(false)
                }
                .pickerStyle(.segmented)

                if recurring {
                    Section("Days (the day the lock starts)") {
                        HStack {
                            ForEach(1...7, id: \.self) { day in
                                let on = weekdays.contains(day)
                                Button(Calendar.current.veryShortWeekdaySymbols[day - 1]) {
                                    if on { weekdays.remove(day) } else { weekdays.insert(day) }
                                }
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(on ? Color.accentColor : Color.secondary.opacity(0.2), in: Circle())
                                .foregroundStyle(on ? Color.white : Color.primary)
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $endTime, displayedComponents: .hourAndMinute)
                } else {
                    DatePicker("Starts", selection: $oneOffStart, in: Date()...)
                    DatePicker("Ends", selection: $oneOffEnd, in: oneOffStart...)
                }
                Toggle("On", isOn: $enabled)

                Section {
                    Text(effectText).font(.callout).foregroundStyle(effect == .delayed ? Color.orange : Color.secondary)
                }

                if let original {
                    Section {
                        Button("Delete schedule", role: .destructive) { confirmDelete = true }
                    }
                    .confirmationDialog("Deleting waits 24 hours before it takes effect.", isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button("Delete after 24h", role: .destructive) {
                            model.saveSchedule(id: original.id, nil)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(original == nil ? "New schedule" : "Edit schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.saveSchedule(id: built.id, built)
                        if model.errorMessage == nil { dismiss() }
                    }
                }
            }
        }
    }

    private var effect: ChangeEffect {
        ChangeRules.effect(old: original, new: built, now: Date())
    }

    private var effectText: String {
        switch effect {
        case .immediate: return "This applies as soon as you save."
        case .delayed: return "This makes the schedule weaker, so it waits 24 hours before it applies."
        }
    }
}
