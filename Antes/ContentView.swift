import Foundation
import SwiftUI

struct ContentView: View {
    @State private var habitText = "10 flexões antes do TikTok"
    @State private var selectedSuggestion: HabitSuggestion = .fitness
    @State private var selectedTab: AppTab = .blocks
    @State private var lockedApps = LockedApp.samples
    @State private var pushupCount = 0
    @State private var restSeconds = 30
    @State private var ritualIsActive = false
    @State private var generatedRitual: AIRitual?
    @State private var isGeneratingRitual = false
    @State private var generationError: String?

    private var selectedApps: [LockedApp] {
        lockedApps.filter(\.isLocked)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        HeaderView()
                        LockedAppsSection(apps: $lockedApps)
                        HabitComposerSection(
                            habitText: $habitText,
                            selectedSuggestion: $selectedSuggestion,
                            isGenerating: isGeneratingRitual,
                            errorMessage: generationError,
                            generateAction: generateRitual
                        )
                        RitualPreviewSection(
                            habitText: habitText,
                            ritual: generatedRitual,
                            pushupCount: $pushupCount,
                            restSeconds: $restSeconds
                        )
                        UnlockRuleSection()
                        ActivateButton(isActive: $ritualIsActive, lockedAppsCount: selectedApps.count)
                        ScheduleRow()
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
                    .padding(.bottom, 24)
                }
                .background(Color.antesBackground)
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Bloqueios", systemImage: selectedTab == .blocks ? "lock.fill" : "lock")
            }
            .tag(AppTab.blocks)

            ReportsPlaceholderView()
                .tabItem { Label("Relatórios", systemImage: "chart.bar") }
                .tag(AppTab.reports)

            DiscoverPlaceholderView()
                .tabItem { Label("Descobrir", systemImage: "safari") }
                .tag(AppTab.discover)

            SettingsPlaceholderView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(.antesBlue)
    }

    private func generateRitual() {
        guard !isGeneratingRitual else { return }

        isGeneratingRitual = true
        generationError = nil

        Task {
            do {
                let ritual = try await RitualGeneratorService().generate(
                    habit: habitText,
                    apps: selectedApps.map(\.name)
                )
                await MainActor.run {
                    generatedRitual = ritual
                    pushupCount = 0
                    restSeconds = 30
                    isGeneratingRitual = false
                }
            } catch {
                await MainActor.run {
                    generationError = "Não consegui gerar agora. Verifique se o backend local está rodando."
                    isGeneratingRitual = false
                }
            }
        }
    }
}

private struct HeaderView: View {
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Antes")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(Color.antesInk)
                Text("Foco primeiro. Apps depois.")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Color.antesMuted)
            }

            Spacer()

            HStack(spacing: 18) {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 19, weight: .bold))
                    Text("7")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.antesGreen)
                .accessibilityLabel("Sequência de 7 dias")

                Button(action: {}) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(Color.antesMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Perfil")
            }
            .padding(.top, 7)
        }
    }
}

private struct LockedAppsSection: View {
    @Binding var apps: [LockedApp]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apps bloqueados hoje")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.antesInk)
                    Text("Eles só desbloqueiam após o hábito.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.antesMuted)
                }

                Spacer()

                Button("Editar") {
                    toggleNextApp()
                }
                .font(.system(size: 16, weight: .semibold))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach($apps) { $app in
                        LockedAppButton(app: $app)
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 2)
            }
        }
    }

    private func toggleNextApp() {
        guard let index = apps.indices.randomElement() else { return }
        apps[index].isLocked.toggle()
    }
}

private struct LockedAppButton: View {
    @Binding var app: LockedApp

    var body: some View {
        Button {
            app.isLocked.toggle()
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(app.palette.background)
                        .frame(width: 70, height: 70)
                        .overlay {
                            Image(systemName: app.systemImage)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(app.palette.foreground)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(.black.opacity(0.05), lineWidth: 1)
                        }

                    if app.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.antesMuted)
                            .frame(width: 28, height: 28)
                            .background(.white, in: Circle())
                            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                            .offset(x: 10, y: -8)
                    }
                }

                Text(app.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.antesInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(app.isLocked ? "Bloqueado" : "Livre")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.antesMuted)
            }
            .frame(width: 78)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(app.name), \(app.isLocked ? "bloqueado" : "liberado")")
    }
}

private struct HabitComposerSection: View {
    @Binding var habitText: String
    @Binding var selectedSuggestion: HabitSuggestion
    let isGenerating: Bool
    let errorMessage: String?
    let generateAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()

            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(Color.antesGreen)

                Text("Crie seu hábito com IA")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.antesInk)
            }

            Text("Descreva o que você quer fazer antes de desbloquear seus apps. A IA cria o ritual ideal para você.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.antesMuted)
                .lineSpacing(3)

            HStack(spacing: 8) {
                TextField("Ex: escrever 3 gratidões antes do Instagram", text: $habitText, axis: .vertical)
                    .font(.system(size: 18, weight: .regular))
                    .lineLimit(1...3)
                    .submitLabel(.done)

                Button {
                    habitText = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.antesMuted)
                }
                .accessibilityLabel("Limpar hábito")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.antesStroke, lineWidth: 1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    SuggestionPill(title: "Sugestões", systemImage: nil, isSelected: false) {}
                    ForEach(HabitSuggestion.allCases) { suggestion in
                        SuggestionPill(
                            title: suggestion.title,
                            systemImage: suggestion.systemImage,
                            isSelected: suggestion == selectedSuggestion
                        ) {
                            selectedSuggestion = suggestion
                            habitText = suggestion.example
                        }
                    }
                }
                .padding(.trailing, 2)
            }

            Button(action: generateAction) {
                HStack(spacing: 10) {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text(isGenerating ? "Gerando ritual..." : "Gerar com OpenAI")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.antesBlue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isGenerating)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct SuggestionPill: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isSelected ? .white : .antesMuted)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(isSelected ? Color.antesBlue : Color.antesSoftSurface, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? .clear : Color.antesStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RitualPreviewSection: View {
    let habitText: String
    let ritual: AIRitual?
    @Binding var pushupCount: Int
    @Binding var restSeconds: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()

            HStack(alignment: .center, spacing: 10) {
                Text(ritual?.title ?? "Prévia do ritual gerado pela IA")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.antesInk)
                Text("Novo")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.antesGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.antesGreen.opacity(0.12), in: Capsule())
            }

            Text(ritualSubtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.antesMuted)

            HStack(alignment: .center, spacing: 18) {
                Image("PushupHabit")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .clipped()

                VStack(spacing: 10) {
                    StepRow(
                        number: "1",
                        title: "Execução",
                        detail: firstStepDetail,
                        systemImage: "figure.strengthtraining.traditional",
                        tint: .antesGreen,
                        trailing: "\(pushupCount)/10",
                        progress: Double(pushupCount) / 10
                    ) {
                        pushupCount = min(10, pushupCount + 1)
                    }

                    StepRow(
                        number: "2",
                        title: "Descanso",
                        detail: secondStepDetail,
                        systemImage: "clock",
                        tint: .antesMuted,
                        trailing: formattedSeconds,
                        progress: Double(30 - restSeconds) / 30
                    ) {
                        restSeconds = max(0, restSeconds - 5)
                    }

                    StepRow(
                        number: "3",
                        title: "Conclusão",
                        detail: thirdStepDetail,
                        systemImage: "checkmark",
                        tint: pushupCount >= 10 ? .antesGreen : .antesMuted,
                        trailing: pushupCount >= 10 ? "OK" : "",
                        progress: pushupCount >= 10 ? 1 : 0
                    ) {
                        pushupCount = 10
                        restSeconds = 0
                    }
                }
            }
        }
    }

    private var ritualSubtitle: String {
        if let ritual {
            return "\(ritual.category) • \(ritual.summary) • ~\(ritual.durationMinutes) min"
        }
        if habitText.localizedCaseInsensitiveContains("gratid") {
            return "Journaling • Presença • ~3 min"
        }
        if habitText.localizedCaseInsensitiveContains("oração") {
            return "Oração • Leitura • ~2 min"
        }
        return "Flexões • Força • ~2 min"
    }

    private var firstStepDetail: String {
        ritual?.steps.first?.detail ?? "10 flexões completas"
    }

    private var secondStepDetail: String {
        guard let steps = ritual?.steps, steps.indices.contains(1) else { return "30 segundos" }
        return steps[1].detail
    }

    private var thirdStepDetail: String {
        guard let steps = ritual?.steps, steps.indices.contains(2) else { return "Marque como concluído" }
        return steps[2].detail
    }

    private var formattedSeconds: String {
        "00:\(String(format: "%02d", restSeconds))"
    }
}

private struct StepRow: View {
    let number: String
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let trailing: String
    let progress: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.14))
                        .frame(width: 42, height: 42)
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(number). \(title)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.antesInk)
                    Text(detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.antesMuted)
                }

                Spacer(minLength: 6)

                if !trailing.isEmpty {
                    ZStack {
                        Circle()
                            .stroke(Color.antesStroke, lineWidth: 3)
                            .frame(width: 50, height: 50)
                        Circle()
                            .trim(from: 0, to: max(0, min(1, progress)))
                            .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        Text(trailing)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.antesMuted)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct UnlockRuleSection: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("🙌")
                .font(.system(size: 24))

            Text("Ao concluir, o TikTok será desbloqueado por 15 minutos.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.antesMuted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button("Alterar") {}
                .font(.system(size: 15, weight: .semibold))
        }
        .padding(14)
        .background(Color.antesBlue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.antesBlue.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct ActivateButton: View {
    @Binding var isActive: Bool
    let lockedAppsCount: Int

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                isActive.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isActive ? "checkmark.shield.fill" : "lock.shield")
                    .font(.system(size: 24, weight: .bold))
                Text(isActive ? "Ritual ativo para \(lockedAppsCount) apps" : "Ativar ritual e bloquear apps")
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? Color.antesGreen : Color.antesBlue)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.white.opacity(0.18))
                            .frame(height: 24)
                            .blur(radius: 12)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white.opacity(0.32), lineWidth: 1)
            }
            .shadow(color: (isActive ? Color.antesGreen : Color.antesBlue).opacity(0.24), radius: 20, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive ? "Ritual ativo" : "Ativar ritual e bloquear apps")
    }
}

private struct ScheduleRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.antesMuted)
                .frame(width: 28)
            Text("Programação: Todos os dias, o dia todo")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.antesMuted)
                .lineLimit(2)
            Spacer()
            Button("Alterar") {}
                .font(.system(size: 15, weight: .semibold))
        }
    }
}

private struct ReportsPlaceholderView: View {
    var body: some View {
        PlaceholderScreen(title: "Relatórios", subtitle: "Veja quanto tempo você recuperou nesta semana.", systemImage: "chart.bar.fill")
    }
}

private struct DiscoverPlaceholderView: View {
    var body: some View {
        PlaceholderScreen(title: "Descobrir", subtitle: "Explore rituais para fé, saúde, gratidão e estudo.", systemImage: "safari.fill")
    }
}

private struct SettingsPlaceholderView: View {
    var body: some View {
        PlaceholderScreen(title: "Ajustes", subtitle: "Configure apps, horários e desbloqueios permitidos.", systemImage: "gearshape.fill")
    }
}

private struct PlaceholderScreen: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Color.antesBlue)
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.antesInk)
            Text(subtitle)
                .font(.system(size: 17, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.antesMuted)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.antesBackground)
    }
}

private enum AppTab: Hashable {
    case blocks
    case reports
    case discover
    case settings
}

private enum HabitSuggestion: String, CaseIterable, Identifiable {
    case scripture
    case gratitude
    case water
    case quiz
    case fitness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scripture: "Oração/Escritura"
        case .gratitude: "Gratidão"
        case .water: "Água"
        case .quiz: "Quiz"
        case .fitness: "Flexões"
        }
    }

    var systemImage: String {
        switch self {
        case .scripture: "book.closed"
        case .gratitude: "heart.fill"
        case .water: "drop.fill"
        case .quiz: "graduationcap.fill"
        case .fitness: "figure.strengthtraining.traditional"
        }
    }

    var example: String {
        switch self {
        case .scripture: "Oração curta e leitura breve antes do Instagram"
        case .gratitude: "Escrever 3 coisas pelas quais sou grato"
        case .water: "Beber água antes de abrir o X"
        case .quiz: "Responder 3 perguntas de matemática antes do YouTube"
        case .fitness: "10 flexões antes do TikTok"
        }
    }
}

private struct LockedApp: Identifiable {
    let id = UUID()
    let name: String
    let systemImage: String
    let palette: AppPalette
    var isLocked: Bool

    static let samples = [
        LockedApp(name: "TikTok", systemImage: "music.note", palette: .init(background: .black, foreground: .white), isLocked: true),
        LockedApp(name: "Instagram", systemImage: "camera.fill", palette: .init(background: .pink.opacity(0.95), foreground: .white), isLocked: true),
        LockedApp(name: "YouTube", systemImage: "play.fill", palette: .init(background: .white, foreground: .red), isLocked: true),
        LockedApp(name: "X", systemImage: "xmark", palette: .init(background: .black, foreground: .white), isLocked: true),
        LockedApp(name: "Discord", systemImage: "gamecontroller.fill", palette: .init(background: .indigo, foreground: .white), isLocked: true)
    ]
}

private struct AppPalette {
    let background: Color
    let foreground: Color
}

private extension Color {
    static let antesBackground = Color(red: 0.986, green: 0.988, blue: 0.992)
    static let antesInk = Color(red: 0.035, green: 0.039, blue: 0.051)
    static let antesMuted = Color(red: 0.415, green: 0.427, blue: 0.486)
    static let antesStroke = Color(red: 0.825, green: 0.842, blue: 0.875)
    static let antesSoftSurface = Color(red: 0.957, green: 0.964, blue: 0.974)
    static let antesBlue = Color(red: 0.000, green: 0.357, blue: 1.000)
    static let antesGreen = Color(red: 0.075, green: 0.690, blue: 0.337)
}

#Preview {
    ContentView()
}
