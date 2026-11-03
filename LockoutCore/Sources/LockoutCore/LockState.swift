import Foundation

/// One running lock: on-demand, the onboarding test, or a scheduled window
/// that has begun.
public struct LockInstance: Codable, Identifiable, Equatable {
    public enum Source: Codable, Equatable {
        case onDemand
        case test
        case schedule(UUID)
    }

    public var id: UUID
    public var source: Source
    /// Wall-clock start and end as they were when the lock was created.
    public var start: Date
    public var end: Date
    /// Both clocks at `start`. Lets us tell how much real time has passed even
    /// if the wall clock has been changed since.
    public var anchor: ClockReading
    /// Bumped when the lock is extended or re-armed, so its DeviceActivity gets
    /// a fresh name and an old one ending does not matter.
    public var generation: Int

    public init(id: UUID = UUID(), source: Source, start: Date, end: Date, anchor: ClockReading, generation: Int = 0) {
        self.id = id
        self.source = source
        self.start = start
        self.end = end
        self.anchor = anchor
        self.generation = generation
    }

    public func trustedNow(_ current: ClockReading) -> Date {
        TrustedClock.now(anchor: anchor, current: current)
    }

    public func isActive(_ current: ClockReading) -> Bool {
        let now = trustedNow(current)
        // Safety net: nothing can keep a lock alive longer than the hard cap
        // after it started, whatever the stored end says.
        guard now.timeIntervalSince(start) < Limits.maxTotalFromStart + 3600 else { return false }
        return now < end
    }

    public func remaining(_ current: ClockReading) -> TimeInterval {
        max(0, end.timeIntervalSince(trustedNow(current)))
    }

    /// When the lock ends in wall-clock terms right now. Differs from `end`
    /// only if the clock has been changed during the lock.
    public func wallEnd(_ current: ClockReading) -> Date {
        current.wall.addingTimeInterval(remaining(current))
    }
}

/// A weakening edit waiting out its cooldown.
public struct PendingChange: Codable, Identifiable, Equatable {
    public var id: UUID
    public var scheduleID: UUID
    /// nil means "delete the schedule".
    public var newValue: Schedule?
    public var requestedAt: Date
    public var effectiveAt: Date

    public init(id: UUID = UUID(), scheduleID: UUID, newValue: Schedule?, requestedAt: Date, effectiveAt: Date) {
        self.id = id
        self.scheduleID = scheduleID
        self.newValue = newValue
        self.requestedAt = requestedAt
        self.effectiveAt = effectiveAt
    }
}

/// The Screen Time passcode the app generated and keeps out of sight.
public struct SealedPasscode: Codable, Equatable {
    public var code: String
    public var createdAt: Date
    public var revealRequestedAt: Date?

    public init(code: String, createdAt: Date, revealRequestedAt: Date? = nil) {
        self.code = code
        self.createdAt = createdAt
        self.revealRequestedAt = revealRequestedAt
    }

    public static func generate(using rng: inout some RandomNumberGenerator) -> String {
        // Screen Time passcodes are 4 digits. Avoid the easy-to-guess ones.
        while true {
            let code = (0..<4).map { _ in String(Int.random(in: 0...9, using: &rng)) }.joined()
            if Set(code).count > 1, !"0123456789".contains(code), !"9876543210".contains(code) {
                return code
            }
        }
    }
}

public struct LogEvent: Codable, Equatable {
    public var date: Date
    public var kind: String
    public var detail: String

    public init(date: Date, kind: String, detail: String) {
        self.date = date
        self.kind = kind
        self.detail = detail
    }
}

public struct OnboardingState: Codable, Equatable {
    public var authorized = false
    public var exemptionPicked = false
    public var messagesRemoved = false
    public var downtimeStepSeen = false
    public var passcodeSealed = false
    public var testLockStartedAt: Date?
    public var testLockPassed = false

    public init() {}

    public var isComplete: Bool {
        authorized && messagesRemoved && passcodeSealed && testLockPassed
    }

    // Every field is optional when reading, so adding a field in a later
    // version never makes an old saved file unreadable.
    enum CodingKeys: String, CodingKey {
        case authorized, exemptionPicked, messagesRemoved, downtimeStepSeen, passcodeSealed, testLockStartedAt, testLockPassed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        authorized = try c.decodeIfPresent(Bool.self, forKey: .authorized) ?? false
        exemptionPicked = try c.decodeIfPresent(Bool.self, forKey: .exemptionPicked) ?? false
        messagesRemoved = try c.decodeIfPresent(Bool.self, forKey: .messagesRemoved) ?? false
        downtimeStepSeen = try c.decodeIfPresent(Bool.self, forKey: .downtimeStepSeen) ?? false
        passcodeSealed = try c.decodeIfPresent(Bool.self, forKey: .passcodeSealed) ?? false
        testLockStartedAt = try c.decodeIfPresent(Date.self, forKey: .testLockStartedAt)
        testLockPassed = try c.decodeIfPresent(Bool.self, forKey: .testLockPassed) ?? false
    }
}
