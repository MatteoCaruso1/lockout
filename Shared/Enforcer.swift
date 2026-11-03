import DeviceActivity
import FamilyControls
import Foundation
import LockoutCore
import ManagedSettings

extension ManagedSettingsStore.Name {
    /// Everything that applies only while a lock is running.
    static let lock = Self("lockout.lock")
    /// "Can't delete apps" between locks while a schedule exists (Q4).
    static let guardian = Self("lockout.guard")
}

/// The single place where the saved state is turned into real restrictions.
///
/// The app and the monitor extension both call `refresh` and nothing else, so
/// there is exactly one code path that locks and exactly one that releases.
enum Enforcer {
    static var calendar: Calendar { Calendar.current }

    /// Returns nil, and changes nothing, only if the saved state cannot be opened.
    @discardableResult
    static func refresh(reason: String) -> (AppState, ClockReading)? {
        let current = DeviceClock.read()
        guard let state = try? StateStore.update({ state -> AppState in
            state.refresh(current, calendar: calendar)
            return state
        }) else { return nil }
        apply(state, current)
        sync(state, current)
        return (state, current)
    }

    static func apply(_ state: AppState, _ current: ClockReading) {
        let lock = ManagedSettingsStore(named: .lock)
        if state.isLocked(current) {
            let exempt = ExemptionStore.load()?.applicationTokens ?? []
            lock.shield.applicationCategories = .all(except: exempt)
            lock.shield.webDomainCategories = .all(except: [])
            lock.webContent.blockedByFilter = .all(except: [])
            lock.application.denyAppRemoval = true
            // Hardening. Some of these may only be honoured for child
            // accounts; the loophole sweep records which ones work.
            lock.dateAndTime.requireAutomaticDateAndTime = true
            lock.siri.denySiri = true
            lock.account.lockAccounts = true
            lock.passcode.lockPasscode = true
            lock.appStore.denyInAppPurchases = true
        } else {
            lock.clearAllSettings()
        }

        let guardian = ManagedSettingsStore(named: .guardian)
        if state.shouldDenyAppRemoval(current) {
            guardian.application.denyAppRemoval = true
        } else {
            guardian.clearAllSettings()
        }
    }

    /// Make the system's DeviceActivity list match `MonitorPlan`.
    static func sync(_ state: AppState, _ current: ClockReading) {
        let center = DeviceActivityCenter()
        let wanted = MonitorPlan.build(state, current, calendar: calendar)
        let wantedNames = Set(wanted.map(\.name))
        let running = Set(center.activities.map(\.rawValue))

        // Stopping an activity makes the system deliver its end event, which
        // runs `refresh` again. That is harmless: the state already says
        // whether a lock is running, so the second pass changes nothing.
        let stale = running.subtracting(wantedNames)
        if !stale.isEmpty {
            center.stopMonitoring(stale.map { DeviceActivityName($0) })
        }

        var failures: [String] = []
        for spec in wanted where !running.contains(spec.name) {
            let schedule = DeviceActivitySchedule(intervalStart: spec.start, intervalEnd: spec.end, repeats: spec.repeats)
            do {
                try center.startMonitoring(DeviceActivityName(spec.name), during: schedule)
            } catch {
                failures.append("\(spec.name): \(error)")
            }
        }
        if !failures.isEmpty {
            try? StateStore.update { state in
                for failure in failures { state.log(current.wall, "monitor", "Could not schedule \(failure)") }
            }
        }
    }
}

/// The apps picked in onboarding that stay usable during a lock (Lockout itself).
enum ExemptionStore {
    static var url: URL { AppGroup.container.appendingPathComponent("exempt.json") }

    static func load() -> FamilyActivitySelection? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    static func save(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        try? data.write(to: url, options: [.atomic, .noFileProtection])
    }
}
