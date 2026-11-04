import SwiftUI

/// Small drawn copies of iOS Settings screens, so an instruction shows the
/// exact thing to tap instead of describing it. Apple gives apps no link into
/// Screen Time settings, so a picture is the clearest guide there is.
struct SettingsMock: View {
    struct Row: Identifiable {
        let id = UUID()
        let title: String
        var icon: String = "app.fill"
        var tint: Color = .gray
        /// Draw the red minus button and pulse it.
        var remove = false
        /// Draw a chevron and highlight the row as "tap here".
        var tap = false
        var value: String?
    }

    let path: [String]
    var header: String?
    let rows: [Row]

    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(path.joined(separator: "  ›  "))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let header {
                Text(header.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 12)
            }
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { item in
                    row(item.element)
                    if item.offset < rows.count - 1 {
                        Divider().padding(.leading, item.element.remove ? 84 : 52)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.3)))
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func row(_ row: Row) -> some View {
        HStack(spacing: 12) {
            if row.remove {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, .red)
                    .scaleEffect(pulse ? 1.2 : 0.9)
            }
            Image(systemName: row.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(row.tint, in: RoundedRectangle(cornerRadius: 7))
            Text(row.title)
            Spacer()
            if let value = row.value {
                Text(value).foregroundStyle(.secondary)
            }
            if row.tap {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(row.tap ? Color.accentColor.opacity(pulse ? 0.25 : 0.08) : .clear)
    }
}

extension SettingsMock {
    /// Settings → Screen Time, with "Always Allowed" highlighted.
    static var screenTimeToAlwaysAllowed: SettingsMock {
        SettingsMock(path: ["Settings", "Screen Time"], header: "Limit usage", rows: [
            Row(title: "Downtime", icon: "moon.fill", tint: .purple),
            Row(title: "App Limits", icon: "hourglass", tint: .orange),
            Row(title: "Always Allowed", icon: "checkmark", tint: .green, tap: true),
        ])
    }

    /// Always Allowed, with the minus buttons pulsing on the apps to remove.
    static var alwaysAllowedList: SettingsMock {
        SettingsMock(path: ["Screen Time", "Always Allowed"], header: "Allowed apps", rows: [
            Row(title: "Phone", icon: "phone.fill", tint: .green),
            Row(title: "Messages", icon: "message.fill", tint: .green, remove: true),
            Row(title: "Maps", icon: "map.fill", tint: .blue, remove: true),
            Row(title: "…any other app listed", icon: "app.fill", tint: .gray, remove: true),
        ])
    }

    /// Settings → Screen Time, with the passcode row highlighted.
    static var screenTimePasscode: SettingsMock {
        SettingsMock(path: ["Settings", "Screen Time"], rows: [
            Row(title: "Lock Screen Time Settings", icon: "lock.fill", tint: .blue, tap: true),
        ])
    }

    /// Settings → Screen Time → Downtime.
    static var downtime: SettingsMock {
        SettingsMock(path: ["Screen Time", "Downtime"], rows: [
            Row(title: "Scheduled", icon: "calendar", tint: .purple, tap: true, value: "On"),
            Row(title: "Block at Downtime", icon: "hand.raised.fill", tint: .red, tap: true, value: "On"),
        ])
    }
}
