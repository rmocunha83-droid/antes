import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

@MainActor
final class ScreenTimeController: ObservableObject {
    @Published var selection: FamilyActivitySelection
    @Published var isPickerPresented = false
    @Published var authorizationStatus: AuthorizationStatus
    @Published var isShieldingEnabled: Bool
    @Published var unlockUntil: Date?
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    init() {
        selection = ScreenTimePolicyStore.loadSelection()
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        isShieldingEnabled = ScreenTimePolicyStore.shieldingEnabled
        unlockUntil = ScreenTimePolicyStore.unlockUntil
    }

    var selectedItemCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    var hasSelection: Bool {
        selectedItemCount > 0
    }

    var selectionSummary: String {
        guard hasSelection else { return "Nenhum app selecionado ainda" }

        var parts: [String] = []
        if !selection.applicationTokens.isEmpty {
            parts.append("\(selection.applicationTokens.count) apps")
        }
        if !selection.categoryTokens.isEmpty {
            parts.append("\(selection.categoryTokens.count) categorias")
        }
        if !selection.webDomainTokens.isEmpty {
            parts.append("\(selection.webDomainTokens.count) sites")
        }
        return parts.joined(separator: " + ")
    }

    var unlockDescription: String? {
        guard let unlockUntil, unlockUntil > Date() else { return nil }
        return unlockUntil.formatted(date: .omitted, time: .shortened)
    }

    func requestAuthorization() async {
        errorMessage = nil

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            statusMessage = "Permissão de Screen Time concedida."
        } catch {
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            errorMessage = "Não consegui ativar a permissão de Screen Time. Verifique os ajustes do iPhone."
        }
    }

    func openPicker() async {
        if authorizationStatus != .approved {
            await requestAuthorization()
        }

        guard authorizationStatus == .approved else { return }
        isPickerPresented = true
    }

    func persistSelection() {
        ScreenTimePolicyStore.saveSelection(selection)
        statusMessage = hasSelection ? "\(selectionSummary) protegidos pelo Antes." : "Escolha os apps que devem passar pelo Antes."

        if isShieldingEnabled {
            ScreenTimeShieldManager.apply(selection: selection)
        }
    }

    func updateCurrentRitual(habit: String, unlockMinutes: Int) {
        ScreenTimePolicyStore.currentHabit = habit.trimmingCharacters(in: .whitespacesAndNewlines)
        ScreenTimePolicyStore.unlockMinutes = unlockMinutes
    }

    func toggleShielding(habit: String, unlockMinutes: Int) async {
        if isShieldingEnabled {
            deactivateShielding()
        } else {
            await activateShielding(habit: habit, unlockMinutes: unlockMinutes)
        }
    }

    func activateShielding(habit: String, unlockMinutes: Int) async {
        if authorizationStatus != .approved {
            await requestAuthorization()
        }

        guard authorizationStatus == .approved else { return }
        guard hasSelection else {
            errorMessage = "Escolha pelo menos um app, categoria ou site para proteger."
            return
        }

        updateCurrentRitual(habit: habit, unlockMinutes: unlockMinutes)
        unlockUntil = nil
        ScreenTimePolicyStore.unlockUntil = nil
        ScreenTimePolicyStore.shieldingEnabled = true
        isShieldingEnabled = true
        ScreenTimeShieldManager.apply(selection: selection)

        do {
            try ScreenTimeScheduleManager.startDailyShieldMonitoring()
            statusMessage = "Ritual ativo para \(selectionSummary)."
            errorMessage = nil
        } catch {
            statusMessage = "Ritual ativo. O iOS pode pedir nova permissão para manter a programação."
            errorMessage = nil
        }
    }

    func deactivateShielding() {
        ScreenTimePolicyStore.shieldingEnabled = false
        ScreenTimePolicyStore.unlockUntil = nil
        isShieldingEnabled = false
        unlockUntil = nil
        ScreenTimeShieldManager.clearShields()
        ScreenTimeScheduleManager.stopAllMonitoring()
        statusMessage = "Bloqueios desligados."
        errorMessage = nil
    }

    func completeRitualAndUnlock(habit: String, unlockMinutes: Int) {
        guard isShieldingEnabled else {
            errorMessage = "Ative o ritual antes de liberar os apps."
            return
        }

        guard hasSelection else {
            errorMessage = "Escolha pelo menos um app, categoria ou site para proteger."
            return
        }

        updateCurrentRitual(habit: habit, unlockMinutes: unlockMinutes)

        let endDate = Date().addingTimeInterval(TimeInterval(unlockMinutes * 60))
        unlockUntil = endDate
        ScreenTimePolicyStore.unlockUntil = endDate
        ScreenTimeShieldManager.clearShields()

        do {
            try ScreenTimeScheduleManager.startUnlockWindow(until: endDate)
            statusMessage = "Liberado até \(endDate.formatted(date: .omitted, time: .shortened))."
            errorMessage = nil
        } catch {
            statusMessage = "Liberado até \(endDate.formatted(date: .omitted, time: .shortened))."
            errorMessage = "Se o iOS não rebloquear sozinho, o Antes rebloqueia quando você voltar ao app."
        }
    }

    func refreshAfterForeground() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        unlockUntil = ScreenTimePolicyStore.unlockUntil

        if isShieldingEnabled, !ScreenTimePolicyStore.isCurrentlyUnlocked {
            ScreenTimePolicyStore.unlockUntil = nil
            unlockUntil = nil
            ScreenTimeShieldManager.apply(selection: selection)
        }
    }
}
