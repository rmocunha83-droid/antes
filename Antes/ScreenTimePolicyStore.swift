@preconcurrency import DeviceActivity
import FamilyControls
import Foundation
@preconcurrency import ManagedSettings

enum AntesScreenTimeConstants {
    static let appGroupIdentifier = "group.com.romeucunha.Antes"
    static var managedStoreName: ManagedSettingsStore.Name { ManagedSettingsStore.Name("antes.primary") }
    static var dailyActivityName: DeviceActivityName { DeviceActivityName("antes.daily-shield") }
    static var unlockActivityName: DeviceActivityName { DeviceActivityName("antes.unlock-window") }
    static let defaultUnlockMinutes = 15
}

enum ScreenTimePolicyStore {
    private enum Keys {
        static let selection = "screenTime.selection"
        static let shieldingEnabled = "screenTime.shieldingEnabled"
        static let currentHabit = "screenTime.currentHabit"
        static let unlockMinutes = "screenTime.unlockMinutes"
        static let unlockUntil = "screenTime.unlockUntil"
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AntesScreenTimeConstants.appGroupIdentifier) ?? .standard
    }

    static func loadSelection() -> FamilyActivitySelection {
        guard let data = defaults.data(forKey: Keys.selection),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    static func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: Keys.selection)
    }

    static var shieldingEnabled: Bool {
        get { defaults.bool(forKey: Keys.shieldingEnabled) }
        set { defaults.set(newValue, forKey: Keys.shieldingEnabled) }
    }

    static var currentHabit: String {
        get { defaults.string(forKey: Keys.currentHabit) ?? "Complete seu ritual saudável no Antes." }
        set { defaults.set(newValue, forKey: Keys.currentHabit) }
    }

    static var unlockMinutes: Int {
        get {
            let value = defaults.integer(forKey: Keys.unlockMinutes)
            return value > 0 ? value : AntesScreenTimeConstants.defaultUnlockMinutes
        }
        set { defaults.set(max(1, newValue), forKey: Keys.unlockMinutes) }
    }

    static var unlockUntil: Date? {
        get { defaults.object(forKey: Keys.unlockUntil) as? Date }
        set { defaults.set(newValue, forKey: Keys.unlockUntil) }
    }

    static var isCurrentlyUnlocked: Bool {
        guard let unlockUntil else { return false }
        return unlockUntil > Date()
    }
}

enum ScreenTimeShieldManager {
    private static var store: ManagedSettingsStore {
        ManagedSettingsStore(named: AntesScreenTimeConstants.managedStoreName)
    }

    static func applySavedPolicyIfNeeded() {
        guard ScreenTimePolicyStore.shieldingEnabled else {
            clearShields()
            return
        }

        guard !ScreenTimePolicyStore.isCurrentlyUnlocked else {
            clearShields()
            return
        }

        apply(selection: ScreenTimePolicyStore.loadSelection())
    }

    static func apply(selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    static func clearShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }
}

enum ScreenTimeScheduleManager {
    static func startDailyShieldMonitoring() throws {
        let center = DeviceActivityCenter()
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        try center.startMonitoring(AntesScreenTimeConstants.dailyActivityName, during: schedule)
    }

    static func stopAllMonitoring() {
        let center = DeviceActivityCenter()
        center.stopMonitoring([
            AntesScreenTimeConstants.dailyActivityName,
            AntesScreenTimeConstants.unlockActivityName
        ])
    }

    static func startUnlockWindow(until unlockUntil: Date) throws {
        let center = DeviceActivityCenter()
        let calendar = Calendar.current
        let now = Date()

        guard calendar.isDate(now, inSameDayAs: unlockUntil), unlockUntil > now else { return }

        let start = calendar.dateComponents([.hour, .minute, .second], from: now)
        let end = calendar.dateComponents([.hour, .minute, .second], from: unlockUntil)
        let schedule = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: false)
        try center.startMonitoring(AntesScreenTimeConstants.unlockActivityName, during: schedule)
    }
}
