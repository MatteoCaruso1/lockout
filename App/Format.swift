import Foundation
import LockoutCore

/// Plain-English text for times, durations, schedules and errors.
enum Format {
    static func countdown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m) min"
        case (_, 0): return h == 1 ? "1 hour" : "\(h) hours"
        default: return "\(h) h \(m) min"
        }
    }

    /// "7:00 PM" today, "Wed 7:00 AM" another day.
    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate(Calendar.current.isDateInToday(date) ? "jmm" : "EEEjmm")
        return f.string(from: date)
    }

    static func dateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEMMMdjmm")
        return f.string(from: date)
    }

    static func minuteOfDay(_ minute: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("jmm")
        return f.string(from: date)
    }

    static func weekdays(_ days: Set<Int>) -> String {
        if days == Schedule.everyDay { return "Every day" }
        if days == Schedule.weekdays { return "Weekdays" }
        if days == Schedule.weekend { return "Weekends" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return days.sorted().map { symbols[$0 - 1] }.joined(separator: ", ")
    }

    static func schedule(_ schedule: Schedule) -> String {
        switch schedule.kind {
        case let .recurring(days, start, end):
            return "\(weekdays(days)), \(minuteOfDay(start)) – \(minuteOfDay(end))"
        case let .oneOff(start, end):
            return "\(dateTime(start)) – \(clock(end))"
        }
    }

    static func error(_ error: Error) -> String {
        switch error {
        case AppState.LockError.tooShort: return "That lock is too short."
        case AppState.LockError.tooLong: return "The longest single lock is \(duration(Limits.maxOnDemand))."
        case AppState.LockError.alreadyLocked: return "A lock is already running."
        case AppState.LockError.notLocked: return "No lock is running."
        case AppState.LockError.extendTooLong: return "A lock can't run longer than 24 hours from when it started."
        case AppState.LockError.scheduleEditDuringLock: return "Schedules can't be changed while a lock is running."
        case AppState.LockError.tooManySchedules: return "You can have up to \(Limits.maxSchedules) schedules."
        case Schedule.ValidationError.noWeekdays: return "Pick at least one day."
        case Schedule.ValidationError.badTime: return "The end has to be after the start."
        case Schedule.ValidationError.tooShort: return "A window has to be at least 15 minutes."
        case Schedule.ValidationError.tooLong: return "A window can be at most 12 hours."
        case Schedule.ValidationError.inThePast: return "That time has already passed."
        default: return error.localizedDescription
        }
    }
}
