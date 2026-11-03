import DeviceActivity
import Foundation

/// Runs on its own, without the app, whenever one of Lockout's activities
/// starts or ends. Whatever the event, it does the same thing: recompute
/// from the saved state. That is what lets locks end even if the app is
/// never opened again.
final class LockoutMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        Enforcer.refresh(reason: "start " + activity.rawValue)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard let result = Enforcer.refresh(reason: "end " + activity.rawValue) else { return }
        let (state, current) = result
        // The end event can arrive a moment before the lock's last second. If
        // only a few seconds are left, wait them out here and release now
        // rather than leaving it to the backup five minutes later.
        let remaining = state.remaining(current)
        if remaining > 0, remaining <= 30 {
            Thread.sleep(forTimeInterval: remaining + 1)
            Enforcer.refresh(reason: "end+wait " + activity.rawValue)
        }
    }
}
