import XCTest
@testable import LockoutCore

/// Fixed clock helpers. Tuesday 3 Nov 2026, 12:00 New York time.
private let calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/New_York")!
    return c
}()

private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
}

private let noon = date(3, 12)

/// A reading `elapsed` real seconds after `noon`, with the wall clock moved by `skew`.
private func reading(_ elapsed: TimeInterval = 0, skew: TimeInterval = 0, boot: String = "boot-1") -> ClockReading {
    ClockReading(wall: noon.addingTimeInterval(elapsed + skew), continuous: 10_000 + elapsed, bootID: boot)
}

final class OnDemandLockTests: XCTestCase {
    func testLockRunsForItsDurationThenEnds() throws {
        var state = AppState()
        try state.startLock(duration: 3600, reading())
        XCTAssertTrue(state.isLocked(reading(3599)))
        XCTAssertFalse(state.isLocked(reading(3600)))
    }

    func testCannotStartTooLongOrTooShort() {
        var state = AppState()
        XCTAssertThrowsError(try state.startLock(duration: Limits.maxOnDemand + 1, reading()))
        XCTAssertThrowsError(try state.startLock(duration: 10, reading()))
    }

    func testCannotStartSecondLockWhileLocked() throws {
        var state = AppState()
        try state.startLock(duration: 3600, reading())
        XCTAssertThrowsError(try state.startLock(duration: 3600, reading(60))) { error in
            XCTAssertEqual(error as? AppState.LockError, .alreadyLocked)
        }
    }

    func testMovingClockForwardDoesNotEndLock() throws {
        var state = AppState()
        try state.startLock(duration: 3600, reading())
        // Ten real minutes later the wall clock is pushed 5 hours ahead.
        let tampered = reading(600, skew: 5 * 3600)
        XCTAssertTrue(state.isLocked(tampered))
        XCTAssertEqual(state.remaining(tampered), 3000, accuracy: 1)
        let notes = state.refresh(tampered, calendar: calendar)
        XCTAssertTrue(notes.contains { if case .clockTampered = $0 { return true } else { return false } })
        XCTAssertTrue(state.isLocked(tampered))
        // ...and it still ends after one real hour.
        XCTAssertFalse(state.isLocked(reading(3600, skew: 5 * 3600)))
    }

    func testAfterRestartFallsBackToWallClock() throws {
        var state = AppState()
        try state.startLock(duration: 3600, reading())
        let rebooted = ClockReading(wall: noon.addingTimeInterval(1800), continuous: 30, bootID: "boot-2")
        XCTAssertTrue(state.isLocked(rebooted))
        XCTAssertEqual(state.remaining(rebooted), 1800, accuracy: 1)
    }

    func testHardCapReleasesEvenIfEndIsCorrupted() throws {
        var state = AppState()
        try state.startLock(duration: 3600, reading())
        state.instances[0].end = noon.addingTimeInterval(1_000_000)
        XCTAssertTrue(state.isLocked(reading(3600 * 20)))
        XCTAssertFalse(state.isLocked(reading(Limits.maxTotalFromStart + 3600)))
    }

    func testExtendUpTo24HoursFromStart() throws {
        var state = AppState()
        try state.startLock(duration: 12 * 3600, reading())
        try state.extend(by: 11 * 3600, reading(60))
        XCTAssertEqual(state.lockedUntil(reading(60)), noon.addingTimeInterval(23 * 3600))
        XCTAssertThrowsError(try state.extend(by: 2 * 3600, reading(120))) { error in
            XCTAssertEqual(error as? AppState.LockError, .extendTooLong)
        }
        XCTAssertEqual(state.instances[0].generation, 1)
    }

    func testExtendWhenNotLockedFails() {
        var state = AppState()
        XCTAssertThrowsError(try state.extend(by: 600, reading()))
    }

    func testRefreshDropsEndedLocks() throws {
        var state = AppState()
        try state.startLock(duration: 120, source: .test, reading())
        state.refresh(reading(121), calendar: calendar)
        XCTAssertTrue(state.instances.isEmpty)
    }
}

final class ScheduleTests: XCTestCase {
    let nightly = Schedule(name: "Night", kind: .recurring(weekdays: Schedule.everyDay, startMinute: 22 * 60, endMinute: 7 * 60))

    func testOvernightWindowCrossesMidnight() {
        XCTAssertNotNil(nightly.activeWindow(at: date(3, 23), calendar: calendar))
        let early = nightly.activeWindow(at: date(4, 6, 59), calendar: calendar)
        XCTAssertEqual(early?.start, date(3, 22))
        XCTAssertEqual(early?.end, date(4, 7))
        XCTAssertNil(nightly.activeWindow(at: date(4, 7), calendar: calendar))
        XCTAssertNil(nightly.activeWindow(at: date(3, 12), calendar: calendar))
    }

    func testWeekdaysOnlyUsesStartDay() {
        // 6 Nov 2026 is a Friday; 7 Nov is Saturday.
        let weekdayNights = Schedule(name: "W", kind: .recurring(weekdays: Schedule.weekdays, startMinute: 22 * 60, endMinute: 7 * 60))
        XCTAssertNotNil(weekdayNights.activeWindow(at: date(7, 2), calendar: calendar), "Friday night runs into Saturday")
        XCTAssertNil(weekdayNights.activeWindow(at: date(7, 23), calendar: calendar), "no Saturday night window")
    }

    func testValidation() {
        XCTAssertThrowsError(try Schedule(name: "x", kind: .recurring(weekdays: [], startMinute: 0, endMinute: 60)).validate(now: noon))
        XCTAssertThrowsError(try Schedule(name: "x", kind: .recurring(weekdays: [2], startMinute: 0, endMinute: 10)).validate(now: noon))
        XCTAssertThrowsError(try Schedule(name: "x", kind: .recurring(weekdays: [2], startMinute: 0, endMinute: 13 * 60)).validate(now: noon))
        XCTAssertThrowsError(try Schedule(name: "x", kind: .oneOff(start: date(3, 10), end: date(3, 11))).validate(now: noon))
        XCTAssertNoThrow(try nightly.validate(now: noon))
    }

    func testScheduleStartsLockOnRefresh() throws {
        var state = AppState()
        try state.editSchedule(id: nightly.id, new: nightly, reading())
        let at2230 = reading(10.5 * 3600)
        state.refresh(at2230, calendar: calendar)
        XCTAssertTrue(state.isLocked(at2230))
        XCTAssertEqual(state.lockedUntil(at2230), date(4, 7))
        // Released at 7:00 the next morning.
        let at0700 = reading(19 * 3600)
        state.refresh(at0700, calendar: calendar)
        XCTAssertFalse(state.isLocked(at0700))
    }

    func testCannotEditDuringLock() throws {
        var state = AppState()
        try state.startLock(duration: 3600, reading())
        XCTAssertThrowsError(try state.editSchedule(id: nightly.id, new: nightly, reading(60))) { error in
            XCTAssertEqual(error as? AppState.LockError, .scheduleEditDuringLock)
        }
    }
}

final class CooldownTests: XCTestCase {
    let nightly = Schedule(name: "Night", kind: .recurring(weekdays: Schedule.everyDay, startMinute: 22 * 60, endMinute: 7 * 60))

    func testRuleClassification() {
        var longer = nightly
        longer.kind = .recurring(weekdays: Schedule.everyDay, startMinute: 21 * 60, endMinute: 8 * 60)
        var shorter = nightly
        shorter.kind = .recurring(weekdays: Schedule.everyDay, startMinute: 23 * 60, endMinute: 7 * 60)
        var fewerDays = nightly
        fewerDays.kind = .recurring(weekdays: Schedule.weekdays, startMinute: 22 * 60, endMinute: 7 * 60)
        var renamed = nightly
        renamed.name = "Bedtime"
        var disabled = nightly
        disabled.enabled = false

        XCTAssertEqual(ChangeRules.effect(old: nil, new: nightly, now: noon), .immediate)
        XCTAssertEqual(ChangeRules.effect(old: nightly, new: longer, now: noon), .immediate)
        XCTAssertEqual(ChangeRules.effect(old: nightly, new: renamed, now: noon), .immediate)
        XCTAssertEqual(ChangeRules.effect(old: nightly, new: shorter, now: noon), .delayed)
        XCTAssertEqual(ChangeRules.effect(old: nightly, new: fewerDays, now: noon), .delayed)
        XCTAssertEqual(ChangeRules.effect(old: nightly, new: disabled, now: noon), .delayed)
        XCTAssertEqual(ChangeRules.effect(old: nightly, new: nil, now: noon), .delayed)
        XCTAssertEqual(ChangeRules.effect(old: disabled, new: nightly, now: noon), .immediate)
    }

    func testDeleteAt959pmStillLocksTonight() throws {
        var state = AppState()
        try state.editSchedule(id: nightly.id, new: nightly, reading())
        // 21:59: try to delete tonight's lock.
        let outcome = try state.editSchedule(id: nightly.id, new: nil, reading(9 * 3600 + 59 * 60))
        guard case .pending = outcome else { return XCTFail("delete should be delayed") }
        let at2230 = reading(10.5 * 3600)
        state.refresh(at2230, calendar: calendar)
        XCTAssertTrue(state.isLocked(at2230))
        XCTAssertEqual(state.schedules.count, 1)
    }

    func testPendingAppliesAfter24hButNotMidWindow() throws {
        var state = AppState()
        try state.editSchedule(id: nightly.id, new: nightly, reading())
        try state.editSchedule(id: nightly.id, new: nil, reading(9 * 3600 + 59 * 60))   // 21:59 Tue
        // Wednesday's window starts at 22:00 and is running at 22:30.
        let wed2230 = reading(34.5 * 3600)
        state.pending[0].effectiveAt = noon.addingTimeInterval(35 * 3600)   // pretend it falls due at 23:00 Wed
        state.refresh(wed2230, calendar: calendar)
        XCTAssertTrue(state.isLocked(wed2230))
        // Due at 23:00, but the window is running, so it waits for 07:00 Thu.
        let wed2330 = reading(35.5 * 3600)
        state.refresh(wed2330, calendar: calendar)
        XCTAssertTrue(state.isLocked(wed2330))
        XCTAssertEqual(state.pending.count, 1)
        XCTAssertEqual(state.schedules.count, 1)
        let thu0700 = reading(43 * 3600)
        state.refresh(thu0700, calendar: calendar)
        XCTAssertFalse(state.isLocked(thu0700))
        XCTAssertTrue(state.schedules.isEmpty)
        XCTAssertTrue(state.pending.isEmpty)
    }

    func testPendingAppliesWhenOutsideWindow() throws {
        var state = AppState()
        try state.editSchedule(id: nightly.id, new: nightly, reading())
        try state.editSchedule(id: nightly.id, new: nil, reading(60))   // 12:01 Tue
        state.refresh(reading(24 * 3600 + 120), calendar: calendar)    // 12:03 Wed
        XCTAssertTrue(state.schedules.isEmpty)
    }

    func testAppRemovalStaysDeniedWhileScheduleOrPendingExists() throws {
        var state = AppState()
        XCTAssertFalse(state.shouldDenyAppRemoval(reading()))
        try state.editSchedule(id: nightly.id, new: nightly, reading())
        XCTAssertTrue(state.shouldDenyAppRemoval(reading()))
        try state.editSchedule(id: nightly.id, new: nil, reading(60))
        XCTAssertTrue(state.shouldDenyAppRemoval(reading(120)))
        state.refresh(reading(24 * 3600 + 120), calendar: calendar)
        XCTAssertFalse(state.shouldDenyAppRemoval(reading(24 * 3600 + 120)))
    }

    func testScheduleLimit() throws {
        var state = AppState()
        for i in 0..<Limits.maxSchedules {
            let s = Schedule(name: "\(i)", kind: .recurring(weekdays: [1], startMinute: i * 60, endMinute: i * 60 + 30))
            try state.editSchedule(id: s.id, new: s, reading())
        }
        let extra = Schedule(name: "x", kind: .recurring(weekdays: [2], startMinute: 0, endMinute: 30))
        XCTAssertThrowsError(try state.editSchedule(id: extra.id, new: extra, reading()))
    }
}

final class PasscodeTests: XCTestCase {
    func testRevealNeeds24hAndNoLock() throws {
        var state = AppState()
        state.passcode = SealedPasscode(code: "4821", createdAt: noon)
        XCTAssertFalse(state.canRevealPasscode(reading()))
        state.requestPasscodeReveal(reading())
        XCTAssertFalse(state.canRevealPasscode(reading(23 * 3600)))
        try state.startLock(duration: 2 * 3600, reading(23 * 3600))
        XCTAssertFalse(state.canRevealPasscode(reading(24 * 3600)), "never during a lock")
        XCTAssertTrue(state.canRevealPasscode(reading(25 * 3600)))
    }

    func testGeneratedCodesAreFourDigitsAndNotTrivial() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<500 {
            let code = SealedPasscode.generate(using: &rng)
            XCTAssertEqual(code.count, 4)
            XCTAssertTrue(code.allSatisfy(\.isNumber))
            XCTAssertGreaterThan(Set(code).count, 1)
            XCTAssertNotEqual(code, "1234")
        }
    }
}

final class MonitorPlanTests: XCTestCase {
    func testShortLockGetsBackdatedStartAndBackup() throws {
        var state = AppState()
        try state.startLock(duration: 120, source: .test, reading())
        let specs = MonitorPlan.build(state, reading(), calendar: calendar)
        XCTAssertEqual(specs.count, 2)
        let lock = try XCTUnwrap(specs.first { $0.name.hasPrefix(MonitorPlan.lockPrefix) })
        let start = calendar.date(from: lock.start)!
        let end = calendar.date(from: lock.end)!
        XCTAssertGreaterThanOrEqual(end.timeIntervalSince(start), Limits.deviceActivityMinInterval)
        XCTAssertEqual(end, noon.addingTimeInterval(120))
        let backup = try XCTUnwrap(specs.first { $0.name.hasPrefix(MonitorPlan.backupPrefix) })
        XCTAssertEqual(calendar.date(from: backup.end)!, noon.addingTimeInterval(120 + Limits.backupDelay))
    }

    func testTamperedClockMovesActivityEnd() throws {
        var state = AppState()
        try state.startLock(duration: 3600, reading())
        let tampered = reading(600, skew: 3 * 3600)
        let lock = try XCTUnwrap(MonitorPlan.build(state, tampered, calendar: calendar).first { $0.name.hasPrefix(MonitorPlan.lockPrefix) })
        let end = calendar.date(from: lock.end)!
        // Real end is noon+1h; on the shifted clock that reads 3h later.
        XCTAssertEqual(end.timeIntervalSince(noon.addingTimeInterval(4 * 3600)), 0, accuracy: 60)
    }

    func testNamesAreStableAcrossCalls() throws {
        var state = AppState()
        try state.startLock(duration: 3600, reading())
        let a = MonitorPlan.build(state, reading(10), calendar: calendar).map(\.name)
        let b = MonitorPlan.build(state, reading(500), calendar: calendar).map(\.name)
        XCTAssertEqual(a, b)
    }

    func testSchedulesAndCooldownFitUnderLimit() throws {
        var state = AppState()
        for i in 0..<Limits.maxSchedules {
            let s = Schedule(name: "\(i)", kind: .recurring(weekdays: [1], startMinute: i * 60, endMinute: i * 60 + 30))
            try state.editSchedule(id: s.id, new: s, reading())
        }
        try state.editSchedule(id: state.schedules[0].id, new: nil, reading())
        try state.startLock(duration: 3600, reading())
        let specs = MonitorPlan.build(state, reading(), calendar: calendar)
        XCTAssertEqual(specs.count, Limits.maxSchedules * 2 + 2 + 1)
        XCTAssertLessThanOrEqual(specs.count, Limits.maxMonitors)
    }
}
