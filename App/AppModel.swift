import FamilyControls
import Foundation
import LockoutCore
import SwiftUI

/// What the screens need to show, and every action they can take. Each action
/// is one coordinated change to the saved state followed by `Enforcer.refresh`.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state = AppState()
    @Published private(set) var current = DeviceClock.read()
    @Published var errorMessage: String?
    @Published var notice: String?

    private var ticker: Timer?
    private var lastRefresh = Date.distantPast

    init() {
        refresh()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    // MARK: Derived

    var isLocked: Bool { state.isLocked(current) }
    var remaining: TimeInterval { state.remaining(current) }
    var wallLockedUntil: Date? { state.wallLockedUntil(current) }
    var calendar: Calendar { Enforcer.calendar }

    // MARK: Refreshing

    func refresh() {
        if let result = Enforcer.refresh(reason: "app") {
            state = result.0
            current = result.1
        } else {
            current = DeviceClock.read()
        }
        lastRefresh = Date()
    }

    /// Once a second: move the countdown, and recompute when a lock has just
    /// ended or a minute has passed (that is also what starts a schedule
    /// while the app is open).
    private func tick() {
        let wasLocked = isLocked
        current = DeviceClock.read()
        if wasLocked != isLocked || Date().timeIntervalSince(lastRefresh) >= 60 {
            refresh()
        }
    }

    /// Called whenever the app comes to the front.
    func becameActive() {
        checkAuthorization()
        refresh()
    }

    /// Notice if Screen Time access has been switched off in Settings. It
    /// cannot be prevented (see LOOPHOLES.md), but it is never silent.
    private func checkAuthorization() {
        let approved = AuthorizationCenter.shared.authorizationStatus == .approved
        mutate { state, now in
            if approved {
                state.lastAuthorizedAt = now.wall
            } else if state.onboarding.authorized {
                let lastSeen = state.lastAuthorizedAt.map { Format.dateTime($0) } ?? "unknown"
                state.log(now.wall, "revoked", "Screen Time access for Lockout was switched off in Settings. Last seen on: \(lastSeen).")
                state.onboarding.authorized = false
            }
        }
    }

    // MARK: Changing state

    /// Apply one change, then refresh. Errors become a plain-English alert.
    @discardableResult
    func mutate<T>(_ body: (inout AppState, ClockReading) throws -> T) -> T? {
        let now = DeviceClock.read()
        do {
            let result = try StateStore.update { state in try body(&state, now) }
            refresh()
            return result
        } catch {
            errorMessage = Format.error(error)
            return nil
        }
    }

    func arm(_ request: ArmRequest) {
        mutate { state, now in
            try state.startLock(duration: request.duration, source: request.source, now)
            if request.source == .test { state.onboarding.testLockStartedAt = now.wall }
        }
    }

    func extend(by seconds: TimeInterval) {
        mutate { state, now in try state.extend(by: seconds, now) }
    }

    func saveSchedule(id: UUID, _ schedule: Schedule?) {
        guard let outcome = mutate({ state, now in try state.editSchedule(id: id, new: schedule, now) }) else { return }
        switch outcome {
        case .applied:
            notice = schedule == nil ? "Schedule deleted." : "Saved. It applies now."
        case .pending(let at):
            notice = "This makes the schedule weaker, so it waits 24 hours. It takes effect \(Format.dateTime(at)). Until then the current schedule still locks you."
        }
    }

    func cancelPending(_ id: UUID) {
        mutate { state, _ in state.cancelPending(id: id) }
    }

    func requestPasscodeReveal() {
        mutate { state, now in state.requestPasscodeReveal(now) }
    }

    func resealPasscode() {
        mutate { state, _ in state.passcode?.revealRequestedAt = nil }
    }

    /// Make a passcode for the onboarding step if there is not one waiting.
    func preparePasscode() {
        guard state.passcode == nil else { return }
        mutate { state, now in
            var rng = SystemRandomNumberGenerator()
            state.passcode = SealedPasscode(code: SealedPasscode.generate(using: &rng), createdAt: now.wall)
        }
    }

    func setOnboarding(_ key: WritableKeyPath<OnboardingState, Bool>, _ value: Bool = true) {
        mutate { state, _ in state.onboarding[keyPath: key] = value }
    }

    func resetTestLock() {
        mutate { state, _ in state.onboarding.testLockStartedAt = nil }
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            setOnboarding(\.authorized)
            mutate { state, now in state.lastAuthorizedAt = now.wall }
        } catch {
            errorMessage = "Screen Time access was not granted (\(error.localizedDescription)). Lockout cannot lock anything without it."
        }
    }

    func saveExemption(_ selection: FamilyActivitySelection) {
        ExemptionStore.save(selection)
        setOnboarding(\.exemptionPicked)
    }

    #if DEBUG
    /// Debug builds only. The release-build check fails if this text is
    /// present in the shipped binary.
    func debugEmergencyRelease() {
        mutate { state, now in
            state.instances.removeAll()
            state.log(now.wall, "debug", "LOCKOUT_DEBUG_EMERGENCY_RELEASE used.")
        }
    }
    #endif
}

/// A lock waiting on the "you cannot end this early" screen.
struct ArmRequest: Identifiable {
    let id = UUID()
    let duration: TimeInterval
    var source: LockInstance.Source = .onDemand
}
