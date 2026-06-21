import DeviceActivity

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        if activity == AntesScreenTimeConstants.dailyActivityName {
            ScreenTimeShieldManager.applySavedPolicyIfNeeded()
        }

        if activity == AntesScreenTimeConstants.unlockActivityName {
            ScreenTimeShieldManager.clearShields()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        if activity == AntesScreenTimeConstants.unlockActivityName {
            ScreenTimePolicyStore.unlockUntil = nil
            ScreenTimeShieldManager.applySavedPolicyIfNeeded()
        }
    }
}
