import Foundation

/// A lock window that starts by itself.
public struct Schedule: Codable, Identifiable, Equatable {
    public enum Kind: Codable, Equatable {
        /// Every chosen weekday (Calendar numbering: 1 = Sunday ... 7 = Saturday),
        /// from `startMinute` to `endMinute` (minutes after midnight). An end at or
        /// before the start means the window runs past midnight into the next day;
        /// the weekday is the day the window STARTS.
        case recurring(weekdays: Set<Int>, startMinute: Int, endMinute: Int)
        /// Once, between two exact moments.
        case oneOff(start: Date, end: Date)
    }

    public var id: UUID
    public var name: String
    public var kind: Kind
    public var enabled: Bool

    public init(id: UUID = UUID(), name: String, kind: Kind, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.kind = kind
        self.enabled = enabled
    }

    public static let everyDay: Set<Int> = Set(1...7)
    public static let weekdays: Set<Int> = Set(2...6)
    public static let weekend: Set<Int> = [1, 7]

    /// Length of one window in seconds.
    public var duration: TimeInterval {
        switch kind {
        case let .recurring(_, start, end):
            return TimeInterval(Self.recurringMinutes(start: start, end: end) * 60)
        case let .oneOff(start, end):
            return end.timeIntervalSince(start)
        }
    }

    static func recurringMinutes(start: Int, end: Int) -> Int {
        let minutes = (end - start + 1440) % 1440
        return minutes == 0 ? 1440 : minutes
    }

    public enum ValidationError: Error, Equatable {
        case noWeekdays, badTime, tooShort, tooLong, inThePast
    }

    public func validate(now: Date) throws {
        switch kind {
        case let .recurring(days, start, end):
            guard !days.isEmpty, days.isSubset(of: Self.everyDay) else { throw ValidationError.noWeekdays }
            guard (0..<1440).contains(start), (0..<1440).contains(end) else { throw ValidationError.badTime }
        case let .oneOff(start, end):
            guard end > start else { throw ValidationError.badTime }
            guard start > now else { throw ValidationError.inThePast }
        }
        guard duration >= Limits.minWindow else { throw ValidationError.tooShort }
        guard duration <= Limits.maxWindow else { throw ValidationError.tooLong }
    }

    /// The window that contains `date`, if one does.
    public func activeWindow(at date: Date, calendar: Calendar) -> DateInterval? {
        guard enabled else { return nil }
        switch kind {
        case .oneOff(let start, let end):
            return (start <= date && date < end) ? DateInterval(start: start, end: end) : nil
        case .recurring:
            // A window that started yesterday can still be running today.
            for offset in [0, -1] {
                if let window = recurringWindow(startingOnDayOf: date, dayOffset: offset, calendar: calendar),
                   window.start <= date, date < window.end {
                    return window
                }
            }
            return nil
        }
    }

    /// The next window that starts strictly after `date`.
    public func nextWindow(after date: Date, calendar: Calendar) -> DateInterval? {
        guard enabled else { return nil }
        switch kind {
        case .oneOff(let start, let end):
            return start > date ? DateInterval(start: start, end: end) : nil
        case .recurring:
            for offset in 0...7 {
                if let window = recurringWindow(startingOnDayOf: date, dayOffset: offset, calendar: calendar),
                   window.start > date {
                    return window
                }
            }
            return nil
        }
    }

    func recurringWindow(startingOnDayOf date: Date, dayOffset: Int, calendar: Calendar) -> DateInterval? {
        guard case let .recurring(days, startMinute, endMinute) = kind,
              let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: date)),
              days.contains(calendar.component(.weekday, from: day)),
              let start = calendar.date(bySettingHour: startMinute / 60, minute: startMinute % 60, second: 0, of: day)
        else { return nil }
        let end = start.addingTimeInterval(TimeInterval(Self.recurringMinutes(start: startMinute, end: endMinute) * 60))
        return DateInterval(start: start, end: end)
    }

    /// Minutes of the week (0 = Sunday 00:00) a recurring schedule covers.
    /// Used to decide whether an edit makes a schedule stronger or weaker.
    var weeklyCoverage: Set<Int> {
        guard enabled, case let .recurring(days, start, end) = kind else { return [] }
        var minutes = Set<Int>()
        let length = Self.recurringMinutes(start: start, end: end)
        for day in days {
            let base = (day - 1) * 1440 + start
            for i in 0..<length { minutes.insert((base + i) % 10080) }
        }
        return minutes
    }
}

/// Whether an edit can apply now or must wait out the cooldown.
public enum ChangeEffect: Equatable {
    /// Stronger or no weaker: applies immediately.
    case immediate
    /// Weaker in any way: waits `Limits.weakenCooldown`.
    case delayed
}

public enum ChangeRules {
    /// Classify replacing `old` with `new` (nil = created / deleted).
    ///
    /// The test is strict on purpose: a change applies immediately only if the
    /// new schedule locks you at every moment the old one did. Moving a window,
    /// even to a longer one that misses a few old minutes, is a weakening.
    public static func effect(old: Schedule?, new: Schedule?, now: Date) -> ChangeEffect {
        guard let old = old else { return .immediate }               // adding a schedule
        if !protects(old, now: now) { return .immediate }             // old one no longer does anything
        guard let new = new, new.enabled else { return .delayed }     // deleting or disabling
        switch (old.kind, new.kind) {
        case (.recurring, .recurring):
            return new.weeklyCoverage.isSuperset(of: old.weeklyCoverage) ? .immediate : .delayed
        case let (.oneOff(oldStart, oldEnd), .oneOff(newStart, newEnd)):
            return (newStart <= oldStart && newEnd >= oldEnd) ? .immediate : .delayed
        default:
            return .delayed
        }
    }

    /// Whether a schedule still has any lock time left in it.
    static func protects(_ schedule: Schedule, now: Date) -> Bool {
        guard schedule.enabled else { return false }
        if case let .oneOff(_, end) = schedule.kind { return end > now }
        return true
    }
}
