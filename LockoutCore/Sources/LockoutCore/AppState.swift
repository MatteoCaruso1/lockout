import Foundation

/// Everything Lockout remembers, saved as one JSON file in the App Group so the
/// app and the extensions see the same thing.
///
/// Every decision is made by recomputing from this state ("is any lock running
/// right now?") rather than by reacting to a single event. That is what makes
/// release safe: any event at all, from any target, ends a lock that is over.
public struct AppState: Codable, Equatable {
    public var onboarding = OnboardingState()
    public var instances: [LockInstance] = []
    public var schedules: [Schedule] = []
    public var pending: [PendingChange] = []
    public var passcode: SealedPasscode?
    public var events: [LogEvent] = []
    public var lastAuthorizedAt: Date?

    public init() {}

    // Every field is optional when reading, so a later version that adds a
    // field can still read a file saved by an earlier one.
    enum CodingKeys: String, CodingKey {
        case onboarding, instances, schedules, pending, passcode, events, lastAuthorizedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        onboarding = try c.decodeIfPresent(OnboardingState.self, forKey: .onboarding) ?? OnboardingState()
        instances = try c.decodeIfPresent([LockInstance].self, forKey: .instances) ?? []
        schedules = try c.decodeIfPresent([Schedule].self, forKey: .schedules) ?? []
        pending = try c.decodeIfPresent([PendingChange].self, forKey: .pending) ?? []
        passcode = try c.decodeIfPresent(SealedPasscode.self, forKey: .passcode)
        events = try c.decodeIfPresent([LogEvent].self, forKey: .events) ?? []
        lastAuthorizedAt = try c.decodeIfPresent(Date.self, forKey: .lastAuthorizedAt)
    }

    // MARK: Is a lock running?

    public func activeInstances(_ current: ClockReading) -> [LockInstance] {
        instances.filter { $0.isActive(current) }
    }

    public func isLocked(_ current: ClockReading) -> Bool {
        !activeInstances(current).isEmpty
    }

    /// The moment every running lock is over (trusted time), or nil if unlocked.
    public func lockedUntil(_ current: ClockReading) -> Date? {
        activeInstances(current).map(\.end).max()
    }

    public func remaining(_ current: ClockReading) -> TimeInterval {
        activeInstances(current).map { $0.remaining(current) }.max() ?? 0
    }

    /// When the lock ends as the phone's clock shows it now. Same as
    /// `lockedUntil` unless the clock was changed during the lock.
    public func wallLockedUntil(_ current: ClockReading) -> Date? {
        isLocked(current) ? current.wall.addingTimeInterval(remaining(current)) : nil
    }

    /// App removal stays blocked while any schedule could still lock, while a
    /// weakening change is waiting, and during any lock (Matteo's Q4 default).
    public func shouldDenyAppRemoval(_ current: ClockReading) -> Bool {
        isLocked(current)
            || !pending.isEmpty
            || schedules.contains { ChangeRules.protects($0, now: current.wall) }
    }

    // MARK: Housekeeping, run on every event

    public enum RefreshNote: Equatable {
        case scheduleStarted(UUID)
        case pendingApplied(UUID)
        case lockEnded(UUID)
        case clockTampered(TimeInterval)
    }

    /// Bring the state up to date. Safe to call any number of times from any target.
    @discardableResult
    public mutating func refresh(_ current: ClockReading, calendar: Calendar) -> [RefreshNote] {
        var notes: [RefreshNote] = []

        for instance in instances where instance.isActive(current)
            && TrustedClock.isTampered(anchor: instance.anchor, current: current) {
            notes.append(.clockTampered(TrustedClock.skew(anchor: instance.anchor, current: current)))
            break
        }

        // Drop locks that are over.
        let ended = instances.filter { !$0.isActive(current) }
        for instance in ended { notes.append(.lockEnded(instance.id)) }
        instances.removeAll { !$0.isActive(current) }

        // Apply weakening changes whose cooldown is over, but never in the
        // middle of that schedule's own window.
        for change in pending where current.wall >= change.effectiveAt {
            let running = instances.contains { $0.source == .schedule(change.scheduleID) }
            if running { continue }
            schedules.removeAll { $0.id == change.scheduleID }
            if let replacement = change.newValue { schedules.append(replacement) }
            pending.removeAll { $0.id == change.id }
            notes.append(.pendingApplied(change.scheduleID))
        }

        // Start scheduled windows that are due and not yet running. This also
        // covers a window whose start event the system never delivered.
        // The system's start event can arrive a moment before the window's
        // first second, so look a little ahead: starting a few seconds early
        // is fine, missing tonight's lock is not.
        let lookahead = current.wall.addingTimeInterval(Limits.scheduleStartLeeway)
        for schedule in schedules {
            guard let window = schedule.activeWindow(at: lookahead, calendar: calendar) else { continue }
            if instances.contains(where: { $0.source == .schedule(schedule.id) }) { continue }
            instances.append(LockInstance(source: .schedule(schedule.id),
                                          start: window.start,
                                          end: window.end,
                                          anchor: current.shifted(toWall: window.start)))
            notes.append(.scheduleStarted(schedule.id))
        }

        // One-off schedules that are fully in the past are finished.
        schedules.removeAll { schedule in
            guard case let .oneOff(_, end) = schedule.kind else { return false }
            return end <= current.wall && !instances.contains { $0.source == .schedule(schedule.id) }
        }

        for note in notes {
            switch note {
            case .clockTampered(let skew):
                log(current.wall, "clock", "Clock is \(Int(skew / 60)) min off real time during a lock; lock kept to real time.")
            case .pendingApplied(let id):
                log(current.wall, "schedule", "Cooldown over; change applied to schedule \(id.uuidString.prefix(8)).")
            default:
                break
            }
        }
        return notes
    }

    // MARK: On-demand locks

    public enum LockError: Error, Equatable {
        case tooShort, tooLong, alreadyLocked, notLocked, extendTooLong, scheduleEditDuringLock, tooManySchedules
    }

    @discardableResult
    public mutating func startLock(duration: TimeInterval, source: LockInstance.Source = .onDemand,
                                   _ current: ClockReading) throws -> LockInstance {
        guard !isLocked(current) else { throw LockError.alreadyLocked }
        guard duration >= Limits.minOnDemand else { throw LockError.tooShort }
        guard duration <= Limits.maxOnDemand else { throw LockError.tooLong }
        let instance = LockInstance(source: source, start: current.wall,
                                    end: current.wall.addingTimeInterval(duration), anchor: current)
        instances.append(instance)
        log(current.wall, "lock", "Locked for \(Int(duration / 60)) min.")
        return instance
    }

    /// Push the end of the current lock out by `extra` seconds.
    ///
    /// An on-demand lock is lengthened in place, up to 24h after it started.
    /// A scheduled lock is never edited; instead a new on-demand lock is added
    /// that runs from now until the later end.
    public mutating func extend(by extra: TimeInterval, _ current: ClockReading) throws {
        guard extra > 0, let until = lockedUntil(current) else { throw LockError.notLocked }
        let newEnd = until.addingTimeInterval(extra)
        if let index = instances.firstIndex(where: { $0.source == .onDemand && $0.isActive(current) }) {
            // `end` and `start` are both in trusted time, so a changed clock
            // cannot stretch the 24h cap.
            guard newEnd.timeIntervalSince(instances[index].start) <= Limits.maxTotalFromStart else { throw LockError.extendTooLong }
            instances[index].end = newEnd
            instances[index].generation += 1
        } else {
            let now = TrustedClock.now(anchor: current, current: current)
            guard newEnd.timeIntervalSince(now) <= Limits.maxTotalFromStart else { throw LockError.extendTooLong }
            instances.append(LockInstance(source: .onDemand, start: now, end: newEnd, anchor: current))
        }
        log(current.wall, "lock", "Extended by \(Int(extra / 60)) min.")
    }

    // MARK: Schedules

    public enum EditOutcome: Equatable {
        case applied
        case pending(effectiveAt: Date)
    }

    /// Create, edit (pass the same id) or delete (`new == nil`, `id` given) a schedule.
    @discardableResult
    public mutating func editSchedule(id: UUID, new: Schedule?, _ current: ClockReading) throws -> EditOutcome {
        guard !isLocked(current) else { throw LockError.scheduleEditDuringLock }
        let now = current.wall
        if let new = new { try new.validate(now: now) }
        let old = schedules.first { $0.id == id }
        if old == nil, new != nil, schedules.count >= Limits.maxSchedules { throw LockError.tooManySchedules }

        // A new edit replaces any waiting one for the same schedule. Dropping a
        // waiting weakening can only make things stricter, so that is safe.
        pending.removeAll { $0.scheduleID == id }

        switch ChangeRules.effect(old: old, new: new, now: now) {
        case .immediate:
            schedules.removeAll { $0.id == id }
            if let new = new { schedules.append(new) }
            log(now, "schedule", new == nil ? "Schedule removed." : "Schedule saved.")
            return .applied
        case .delayed:
            let effectiveAt = now.addingTimeInterval(Limits.weakenCooldown)
            pending.append(PendingChange(scheduleID: id, newValue: new, requestedAt: now, effectiveAt: effectiveAt))
            log(now, "schedule", "Weakening change queued; applies after the 24h cooldown.")
            return .pending(effectiveAt: effectiveAt)
        }
    }

    /// Cancel a waiting weakening change. Always allowed: it keeps things stricter.
    public mutating func cancelPending(id: UUID) {
        pending.removeAll { $0.id == id }
    }

    /// The next moment any schedule starts, if one exists.
    public func nextScheduledStart(after date: Date, calendar: Calendar) -> Date? {
        schedules.compactMap { $0.nextWindow(after: date, calendar: calendar)?.start }.min()
    }

    // MARK: Sealed passcode

    public mutating func requestPasscodeReveal(_ current: ClockReading) {
        guard passcode != nil, passcode?.revealRequestedAt == nil else { return }
        passcode?.revealRequestedAt = current.wall
        log(current.wall, "passcode", "Passcode requested; viewable in 24h if no lock is running then.")
    }

    /// The passcode can be shown 24h after it was asked for, and never during a lock.
    public func canRevealPasscode(_ current: ClockReading) -> Bool {
        guard let requested = passcode?.revealRequestedAt else { return false }
        return current.wall >= requested.addingTimeInterval(Limits.passcodeRevealDelay) && !isLocked(current)
    }

    // MARK: Log

    public mutating func log(_ date: Date, _ kind: String, _ detail: String) {
        events.append(LogEvent(date: date, kind: kind, detail: detail))
        if events.count > Limits.maxLogEvents { events.removeFirst(events.count - Limits.maxLogEvents) }
    }
}
