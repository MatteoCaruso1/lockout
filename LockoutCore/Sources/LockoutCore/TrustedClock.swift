import Foundation

/// One look at both clocks at the same moment.
///
/// `wall` is the normal date and time, which the user can change in Settings.
/// `continuous` is seconds since the phone booted, counting sleep, which the
/// user cannot change. `bootID` changes on every restart, and `continuous`
/// only means something within one boot.
public struct ClockReading: Codable, Equatable {
    public var wall: Date
    public var continuous: TimeInterval
    public var bootID: String

    public init(wall: Date, continuous: TimeInterval, bootID: String) {
        self.wall = wall
        self.continuous = continuous
        self.bootID = bootID
    }

    /// The reading this one would have been at another wall time, assuming
    /// nobody touched the clock in between. Used to anchor a lock that
    /// logically started before the moment we noticed it.
    public func shifted(toWall date: Date) -> ClockReading {
        ClockReading(wall: date, continuous: continuous - wall.timeIntervalSince(date), bootID: bootID)
    }
}

public enum TrustedClock {
    /// What time it really is, judged from `anchor`.
    ///
    /// Within the same boot this ignores the wall clock entirely, so moving the
    /// clock forward cannot end a lock early. After a restart there is no
    /// trustworthy reference left, so it falls back to the wall clock (the
    /// automatic-date-and-time setting is the defence there).
    public static func now(anchor: ClockReading, current: ClockReading) -> Date {
        guard anchor.bootID == current.bootID, current.continuous >= anchor.continuous else {
            return current.wall
        }
        return anchor.wall.addingTimeInterval(current.continuous - anchor.continuous)
    }

    /// Seconds the wall clock is ahead of the trusted clock (negative if behind).
    /// Zero when it cannot be measured.
    public static func skew(anchor: ClockReading, current: ClockReading) -> TimeInterval {
        guard anchor.bootID == current.bootID, current.continuous >= anchor.continuous else { return 0 }
        return current.wall.timeIntervalSince(now(anchor: anchor, current: current))
    }

    public static func isTampered(anchor: ClockReading, current: ClockReading) -> Bool {
        abs(skew(anchor: anchor, current: current)) > Limits.clockSkewTolerance
    }
}
