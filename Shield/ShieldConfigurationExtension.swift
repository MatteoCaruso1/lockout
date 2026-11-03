import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen shown over a blocked app or website. It only shows when the
/// lock ends. There is deliberately no ShieldAction extension, so its one
/// button can only close the app.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: .black,
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(text: "Locked", color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle(), color: .lightGray),
            primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: nil
        )
    }

    private func subtitle() -> String {
        let current = DeviceClock.read()
        guard let state = StateStore.load(), let wallUntil = state.wallLockedUntil(current) else {
            return "Lockout is on."
        }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate(Calendar.current.isDateInToday(wallUntil) ? "jmm" : "EEEjmm")
        return "Locked until \(formatter.string(from: wallUntil))."
    }
}
