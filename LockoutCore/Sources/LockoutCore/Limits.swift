import Foundation

/// Every hard number in the app lives here, so the safety caps are in one place.
public enum Limits {
    /// Longest single on-demand lock (Matteo approved 12h, 2026-11-03).
    public static let maxOnDemand: TimeInterval = 12 * 3600
    /// Extending may push a lock to at most this long after it started.
    public static let maxTotalFromStart: TimeInterval = 24 * 3600
    /// Shortest on-demand lock (the onboarding test lock is 2 minutes).
    public static let minOnDemand: TimeInterval = 60
    /// Scheduled windows: Apple's DeviceActivity minimum and our 12h cap.
    public static let minWindow: TimeInterval = 15 * 60
    public static let maxWindow: TimeInterval = 12 * 3600
    /// A change that weakens a schedule waits this long.
    public static let weakenCooldown: TimeInterval = 24 * 3600
    /// The sealed passcode is shown this long after it is asked for.
    public static let passcodeRevealDelay: TimeInterval = 24 * 3600
    /// Each schedule uses 2 DeviceActivity slots (window + backup); Apple
    /// allows about 20 per app, and locks and the cooldown need 3 more.
    public static let maxSchedules = 6
    public static let maxMonitors = 20
    /// DeviceActivity refuses intervals shorter than 15 minutes.
    public static let deviceActivityMinInterval: TimeInterval = 15 * 60
    /// The backup release fires this long after a lock should have ended.
    public static let backupDelay: TimeInterval = 5 * 60
    /// Wall clock and trusted clock may disagree by this much before we call it tampering.
    public static let clockSkewTolerance: TimeInterval = 120
    /// A schedule's window may begin this many seconds before its start time.
    public static let scheduleStartLeeway: TimeInterval = 60
    /// Seconds on the "you can still cancel" screen.
    public static let armingCountdown = 10
    public static let presetHours = [1, 2, 3, 4, 6, 8]
    public static let testLockDuration: TimeInterval = 120
    public static let maxLogEvents = 200
}
