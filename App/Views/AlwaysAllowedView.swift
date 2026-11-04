import SwiftUI
import UIKit

/// iOS never blocks an app on its Always Allowed list, and no app can change
/// that list. Messages and Maps are on it by default. This screen shows,
/// with pictures, how to empty it. Used in setup and from Home.
struct AlwaysAllowedSteps: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("iOS always lets a few apps through")
                .font(.title2.bold())
            Text("Apps on iOS's **Always Allowed** list are never blocked, by Lockout or anything else. **Messages** and **Maps** are on it by default. To block them too, remove them there. Phone and emergency calls always work.")
            step(1, "In Settings, open **Screen Time**, then **Always Allowed**.")
            SettingsMock.screenTimeToAlwaysAllowed
            step(2, "Tap **Edit** if you see it, then the red minus next to every app except Phone, then **Remove**.")
            SettingsMock.alwaysAllowedList
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            } label: {
                Label("Open Settings", systemImage: "gear")
            }
            Text("Settings may open on Lockout's own page. Tap **‹ Settings** at the top left, then Screen Time.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(n)").bold().frame(width: 22, height: 22).background(Circle().fill(Color.accentColor.opacity(0.3)))
            Text(LocalizedStringKey(text))
        }
    }
}

/// The same steps opened from Home's "Make it stricter" card.
struct AlwaysAllowedView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AlwaysAllowedSteps()
                Button {
                    model.setOnboarding(\.messagesRemoved)
                    dismiss()
                } label: {
                    Text("Done, only Phone is left").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(24)
        }
        .navigationTitle("Always Allowed")
        .navigationBarTitleDisplayMode(.inline)
    }
}
