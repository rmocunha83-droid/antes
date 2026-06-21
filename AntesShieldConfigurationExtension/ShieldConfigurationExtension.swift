import ManagedSettings
import ManagedSettingsUI
import UIKit

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
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor(red: 0.986, green: 0.988, blue: 0.992, alpha: 1),
            icon: UIImage(systemName: "lock.shield.fill"),
            title: .init(text: "Antes de continuar", color: UIColor(red: 0.035, green: 0.039, blue: 0.051, alpha: 1)),
            subtitle: .init(text: subtitle, color: UIColor(red: 0.415, green: 0.427, blue: 0.486, alpha: 1)),
            primaryButtonLabel: .init(text: "Abrir Antes", color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.0, green: 0.357, blue: 1.0, alpha: 1),
            secondaryButtonLabel: .init(text: "Agora não", color: UIColor(red: 0.415, green: 0.427, blue: 0.486, alpha: 1))
        )
    }

    private var subtitle: String {
        let habit = ScreenTimePolicyStore.currentHabit
        let minutes = ScreenTimePolicyStore.unlockMinutes
        return "Faça seu ritual: \(habit). Depois libere seus apps por \(minutes) minutos."
    }
}
