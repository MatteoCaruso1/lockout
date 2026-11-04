import LockoutCore
import SwiftUI

/// The last stop before a lock: a plain warning, then a short countdown that
/// can still be cancelled. Once it reaches zero there is no way back.
struct ArmView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let request: ArmRequest
    @State private var countdown: Int?
    @State private var locking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("You cannot end this early.")
                .font(.largeTitle.bold())
            Text("For \(Format.duration(request.duration)), until \(Format.clock(Date().addingTimeInterval(request.duration))), every app and website will be blocked. Phone calls and emergency calls still work. Lockout will show only a countdown.")
            Text("Not even restarting the phone or deleting Lockout will end it.")
                .foregroundStyle(.secondary)
            Spacer()
            if locking {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Locking…").font(.title)
                }
                .frame(maxWidth: .infinity)
            } else if let countdown {
                Text("Locking in \(countdown)…")
                    .font(.title.monospacedDigit())
                    .frame(maxWidth: .infinity)
                Button(role: .cancel) {
                    self.countdown = nil
                    dismiss()
                } label: {
                    Text("Cancel").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button {
                    countdown = Limits.armingCountdown
                } label: {
                    Text("Lock me out for \(Format.duration(request.duration))").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                Button("Not now") { dismiss() }
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .interactiveDismissDisabled(countdown != nil || locking)
        .task(id: countdown) {
            guard let value = countdown else { return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard countdown == value else { return }
            if value <= 1 {
                // Past the point of no return: Cancel disappears now, before
                // the work starts, not after it.
                locking = true
                await model.arm(request)
                dismiss()
            } else {
                countdown = value - 1
            }
        }
    }
}
