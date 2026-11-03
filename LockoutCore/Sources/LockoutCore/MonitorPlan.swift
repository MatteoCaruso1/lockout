import Foundation

/// One DeviceActivity the system should be watching, in plain terms.
///
/// The name carries everything that defines the activity, so "same name" means
/// "same activity" and syncing is just: stop names no longer wanted, start
/// names not yet running.
public struct MonitorSpec: Equatable, Hashable {
    public var name: String
    public var start: DateComponents
    public var end: DateComponents
    public var repeats: Bool

    public init(name: String, start: DateComponents, end: DateComponents, repeats: Bool) {
        self.name = name
        self.start = start
        self.end = end
        self.repeats = repeats
    }
}

public enum MonitorPlan {
    public static let lockPrefix = "lock."
    public static let backupPrefix = "backup."
    public static let schedulePrefix = "sched."
    public static let scheduleBackupPrefix = "schedb."
    public static let cooldownPrefix = "cooldown."

    /// Every activity that should exist for `state` right now.
    ///
    /// Each on-demand lock gets two: the lock itself, and a backup that ends
    /// 5 minutes after it. Either one ending makes the monitor extension
    /// recompute, and recomputing releases a lock that is over. Each schedule
    /// likewise gets its window plus a backup just after it.
    public static func build(_ state: AppState, _ current: ClockReading, calendar: Calendar) -> [MonitorSpec] {
        var specs: [MonitorSpec] = []
        let now = current.wall

        for instance in state.activeInstances(current) {
            guard instance.source == .onDemand || instance.source == .test else { continue }
            // If the clock has been changed mid-lock, the activity must end
            // when the lock REALLY ends, expressed on the changed clock.
            let tampered = TrustedClock.isTampered(anchor: instance.anchor, current: current)
            let end = tampered ? roundUpToMinute(instance.wallEnd(current), calendar: calendar) : instance.end
            let tag = "\(short(instance.id)).\(instance.generation).\(Int(end.timeIntervalSince1970))"
            specs.append(oneShot(name: lockPrefix + tag, endingAt: end, now: now, calendar: calendar))
            specs.append(oneShot(name: backupPrefix + tag, endingAt: end.addingTimeInterval(Limits.backupDelay),
                                 now: now, calendar: calendar))
        }

        for schedule in state.schedules where schedule.enabled {
            switch schedule.kind {
            case let .recurring(_, startMinute, endMinute):
                let tag = "\(short(schedule.id)).\(startMinute)-\(endMinute)"
                specs.append(MonitorSpec(name: schedulePrefix + tag,
                                         start: hourMinute(startMinute), end: hourMinute(endMinute), repeats: true))
                let backupStart = (endMinute + Int(Limits.backupDelay / 60)) % 1440
                let backupEnd = (backupStart + Int(Limits.deviceActivityMinInterval / 60)) % 1440
                specs.append(MonitorSpec(name: scheduleBackupPrefix + tag,
                                         start: hourMinute(backupStart), end: hourMinute(backupEnd), repeats: true))
            case let .oneOff(start, end):
                guard end > now else { continue }
                let tag = "\(short(schedule.id)).\(Int(start.timeIntervalSince1970))-\(Int(end.timeIntervalSince1970))"
                specs.append(MonitorSpec(name: schedulePrefix + tag,
                                         start: full(start, calendar), end: full(end, calendar), repeats: false))
                let backupStart = end.addingTimeInterval(Limits.backupDelay)
                specs.append(MonitorSpec(name: scheduleBackupPrefix + tag,
                                         start: full(backupStart, calendar),
                                         end: full(backupStart.addingTimeInterval(Limits.deviceActivityMinInterval), calendar),
                                         repeats: false))
            }
        }

        // One cooldown activity, for the next waiting change. When it ends the
        // extension applies every change that is due, then plans the next one.
        if let due = state.pending.map(\.effectiveAt).filter({ $0 > now }).min() {
            specs.append(oneShot(name: cooldownPrefix + String(Int(due.timeIntervalSince1970)),
                                 endingAt: due, now: now, calendar: calendar))
        }

        return Array(specs.prefix(Limits.maxMonitors))
    }

    /// A non-repeating activity that ends at `end`. DeviceActivity refuses
    /// intervals under 15 minutes, so a short one is given a start in the past;
    /// the system then treats it as already running and only the end matters.
    static func oneShot(name: String, endingAt end: Date, now: Date, calendar: Calendar) -> MonitorSpec {
        let start = min(now, end.addingTimeInterval(-(Limits.deviceActivityMinInterval + 60)))
        return MonitorSpec(name: name, start: full(start, calendar), end: full(end, calendar), repeats: false)
    }

    static func full(_ date: Date, _ calendar: Calendar) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }

    static func hourMinute(_ minute: Int) -> DateComponents {
        DateComponents(hour: minute / 60, minute: minute % 60)
    }

    static func roundUpToMinute(_ date: Date, calendar: Calendar) -> Date {
        let seconds = date.timeIntervalSince1970
        return Date(timeIntervalSince1970: (seconds / 60).rounded(.up) * 60)
    }

    static func short(_ id: UUID) -> String {
        String(id.uuidString.prefix(8))
    }
}
