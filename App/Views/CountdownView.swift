import LockoutCore
import SwiftUI

/// The whole app during a lock: time left, when it ends, and Extend.
/// There is no way from here to settings, schedules or anything else.
struct CountdownView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showExtend = false

    private let extensions: [TimeInterval] = [15 * 60, 30 * 60, 3600, 2 * 3600]

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(Format.countdown(model.remaining))
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if let until = model.wallLockedUntil {
                Text("Locked until \(Format.clock(until))")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Text("This lock cannot be ended early.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Extend") { showExtend = true }
                .buttonStyle(.bordered)
            #if DEBUG
            Button("DEBUG: emergency release") { model.debugEmergencyRelease() }
                .font(.caption)
                .foregroundStyle(.red)
            #endif
        }
        .padding()
        .confirmationDialog("Make this lock longer? You can't undo this.", isPresented: $showExtend, titleVisibility: .visible) {
            ForEach(extensions, id: \.self) { seconds in
                Button("+ \(Format.duration(seconds))") { model.extend(by: seconds) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
