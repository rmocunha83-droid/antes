import Foundation
import SwiftUI

struct ContentView: View {
    @State private var habitText = "10 flexões antes do TikTok"
    @State private var selectedSuggestion: HabitSuggestion = .fitness
    @State private var profileIsPresented = false
    @State private var lockedApps = LockedApp.samples
    @State private var pushupCount = 0
    @State private var restSeconds = 30
    @State private var ritualIsActive = false
    @State private var generatedRitual: AIRitual?
    @State private var isGeneratingRitual = false

    private var lockedAppNames: [String] {
        lockedApps.filter(\.isLocked).map(\.name)
    }

    private var activeRitual: AIRitual {
        generatedRitual ?? .localPreview(for: habitText)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HeaderView {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            profileIsPresented.toggle()
                        }
                    }

                    LockedAppsSection(apps: $lockedApps)
                        .padding(.top, 42)

                    HabitComposerSection(
                        habitText: $habitText,
                        selectedSuggestion: $selectedSuggestion,
                        suggestionAction: selectSuggestion
                    )
                    .padding(.top, 42)

                    RitualPreviewSection(
                        habitText: habitText,
                        ritual: activeRitual,
                        pushupCount: $pushupCount,
                        restSeconds: $restSeconds
                    )
                    .padding(.top, 34)

                    UnlockRuleSection()
                        .padding(.top, 26)

                    ActivateButton(
                        isActive: ritualIsActive,
                        isGenerating: isGeneratingRitual,
                        lockedAppsCount: lockedAppNames.count,
                        action: toggleRitual
                    )
                    .padding(.top, 28)

                    ScheduleRow()
                        .padding(.top, 22)

                    AppFooterView()
                        .padding(.top, 30)
                }
                .padding(.horizontal, 22)
                .padding(.top, 34)
                .padding(.bottom, 34)
            }
            .background(Color.antesBackground)

            if profileIsPresented {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            profileIsPresented = false
                        }
                    }

                ProfilePanel()
                    .frame(width: 310)
                    .padding(.top, 84)
                    .padding(.trailing, 22)
                    .transition(.scale(scale: 0.96, anchor: .topTrailing).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .tint(.antesBlue)
    }

    private func selectSuggestion(_ suggestion: HabitSuggestion) {
        selectedSuggestion = suggestion
        habitText = suggestion.example
        generateRitual(for: suggestion.example)
    }

    private func toggleRitual() {
        guard !isGeneratingRitual else { return }

        if ritualIsActive {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                ritualIsActive = false
            }
            return
        }

        generateRitual(for: habitText) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                ritualIsActive = true
            }
        }
    }

    private func generateRitual(for habit: String, completion: (() -> Void)? = nil) {
        let trimmedHabit = habit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHabit.isEmpty, !isGeneratingRitual else {
            completion?()
            return
        }

        isGeneratingRitual = true

        Task {
            let ritual: AIRitual

            do {
                ritual = try await RitualGeneratorService().generate(
                    habit: trimmedHabit,
                    apps: lockedAppNames.isEmpty ? ["apps bloqueados"] : lockedAppNames
                )
            } catch {
                ritual = .localPreview(for: trimmedHabit)
            }

            await MainActor.run {
                generatedRitual = ritual
                pushupCount = 0
                restSeconds = 30
                isGeneratingRitual = false
                completion?()
            }
        }
    }
}

private struct HeaderView: View {
    let profileAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Antes")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(Color.antesInk)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.antesGreen)
                        .frame(width: 4, height: 24)
                    Text("Foco primeiro. Apps depois.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.antesMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    Text("🔥")
                        .font(.system(size: 17))
                    Text("7 dias")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.antesInk)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.top, 8)
                .accessibilityLabel("Sequência de 7 dias")

                Button(action: profileAction) {
                    Image("ProfileAvatar")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        }
                        .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Abrir perfil")
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

private struct LockedAppsSection: View {
    @Binding var apps: [LockedApp]

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 52), spacing: 8),
        count: 5
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Apps bloqueados hoje")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.antesInk)
                    Text("Eles só desbloqueiam após o hábito.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.antesMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button("Editar") {
                    toggleRandomApp()
                }
                .font(.system(size: 15, weight: .bold))
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach($apps) { $app in
                    LockedAppButton(app: $app)
                }
            }
        }
    }

    private func toggleRandomApp() {
        guard let index = apps.indices.randomElement() else { return }
        apps[index].isLocked.toggle()
    }
}

private struct LockedAppButton: View {
    @Binding var app: LockedApp

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                app.isLocked.toggle()
            }
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(app.palette.background)
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: app.systemImage)
                                .font(.system(size: app.symbolSize, weight: .bold))
                                .foregroundStyle(app.palette.foreground)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(app.palette.stroke, lineWidth: app.palette.strokeWidth)
                        }
                        .shadow(color: .black.opacity(app.palette.shadowOpacity), radius: 9, y: 4)

                    if app.isLocked {
                        Text("🔒")
                            .font(.system(size: 13))
                            .frame(width: 27, height: 27)
                            .background(.white, in: Circle())
                            .shadow(color: .black.opacity(0.16), radius: 7, y: 3)
                            .offset(x: 9, y: -8)
                    }
                }

                Text(app.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.antesInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(app.isLocked ? "Bloqueado" : "Livre")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.antesMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(app.name), \(app.isLocked ? "bloqueado" : "livre")")
    }
}

private struct HabitComposerSection: View {
    @Binding var habitText: String
    @Binding var selectedSuggestion: HabitSuggestion
    let suggestionAction: (HabitSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .padding(.bottom, 18)

            HStack(spacing: 12) {
                Text("✦")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(Color.antesGreen)

                Text("Crie seu hábito com IA")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.antesInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Descreva o que você quer fazer antes de desbloquear seus apps. A IA cria o ritual ideal para você.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.antesMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

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
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel("Limpar hábito")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.antesInputStroke, lineWidth: 1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Text("Sugestões")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0.54, green: 0.56, blue: 0.60))
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(Color(red: 0.933, green: 0.941, blue: 0.957), in: Capsule())

                    ForEach(HabitSuggestion.primaryCases) { suggestion in
                        SuggestionPill(
                            suggestion: suggestion,
                            isSelected: suggestion == selectedSuggestion
                        ) {
                            suggestionAction(suggestion)
                        }
                    }
                }
                .padding(.trailing, 2)
            }
        }
    }
}

private struct SuggestionPill: View {
    let suggestion: HabitSuggestion
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(suggestion.emoji)
                    .font(.system(size: 14))
                    .frame(width: 24, height: 24)
                    .background(suggestion.tint.opacity(0.13), in: Circle())
                Text(suggestion.title)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color(red: 0.275, green: 0.290, blue: 0.341))
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(.white, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.antesBlue.opacity(0.3) : Color.antesStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RitualPreviewSection: View {
    let habitText: String
    let ritual: AIRitual
    @Binding var pushupCount: Int
    @Binding var restSeconds: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .padding(.bottom, 12)

            HStack(alignment: .center, spacing: 10) {
                Text(ritual.title.isEmpty ? "Prévia do ritual gerado pela IA" : ritual.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.antesInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Novo")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.antesGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.antesGreen.opacity(0.12), in: Capsule())
            }

            Text("\(ritual.category) • \(ritual.summary) • ~\(ritual.durationMinutes) min")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.antesMuted)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    ritualImage
                        .frame(width: 150, height: 118)

                    steps
                }

                VStack(alignment: .leading, spacing: 16) {
                    ritualImage
                        .frame(maxWidth: .infinity)
                        .frame(height: 178)

                    steps
                }
            }
        }
    }

    private var ritualImage: some View {
        Image("PushupHabit")
            .resizable()
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .clipped()
    }

    private var steps: some View {
        VStack(spacing: 9) {
            StepRow(
                title: stepTitle(at: 0, fallback: "Execução"),
                detail: stepDetail(at: 0, fallback: "10 flexões completas"),
                symbol: "⌁",
                trailing: "\(pushupCount)/10",
                progress: Double(pushupCount) / 10
            ) {
                pushupCount = min(10, pushupCount + 1)
            }

            StepRow(
                title: stepTitle(at: 1, fallback: "Descanso"),
                detail: stepDetail(at: 1, fallback: "30 segundos"),
                symbol: "◷",
                trailing: "00:\(String(format: "%02d", restSeconds))",
                progress: Double(30 - restSeconds) / 30
            ) {
                restSeconds = max(0, restSeconds - 5)
            }

            StepRow(
                title: stepTitle(at: 2, fallback: "Conclusão"),
                detail: stepDetail(at: 2, fallback: "Marque como concluído"),
                symbol: "✓",
                trailing: pushupCount >= 10 && restSeconds == 0 ? "OK" : "",
                progress: pushupCount >= 10 && restSeconds == 0 ? 1 : 0
            ) {
                pushupCount = 10
                restSeconds = 0
            }
        }
    }

    private func stepTitle(at index: Int, fallback: String) -> String {
        guard ritual.steps.indices.contains(index) else { return "\(index + 1). \(fallback)" }
        return "\(index + 1). \(ritual.steps[index].title)"
    }

    private func stepDetail(at index: Int, fallback: String) -> String {
        guard ritual.steps.indices.contains(index) else { return fallback }
        return ritual.steps[index].detail
    }
}

private struct StepRow: View {
    let title: String
    let detail: String
    let symbol: String
    let trailing: String
    let progress: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 9) {
                Text(symbol)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.antesGreen)
                    .frame(width: 38, height: 38)
                    .background(Color.antesGreen.opacity(0.14), in: Circle())
                    .rotationEffect(symbol == "⌁" ? .degrees(90) : .zero)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.antesInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.antesMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                progressBadge
            }
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var progressBadge: some View {
        if !trailing.isEmpty {
            ZStack {
                Circle()
                    .stroke(Color.antesStroke, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(Color.antesGreen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(trailing)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.antesMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
                    .padding(.horizontal, 4)
            }
            .frame(width: 46, height: 46)
            .fixedSize()
        }
    }
}

private struct UnlockRuleSection: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("🙌")
                .font(.system(size: 24))

            Text("Ao concluir, o TikTok será desbloqueado por 15 minutos.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.antesMuted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button("Alterar") {}
                .font(.system(size: 15, weight: .bold))
        }
        .padding(14)
        .background(Color.antesBlue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.antesBlue.opacity(0.25), lineWidth: 1)
        }
    }
}

private struct ActivateButton: View {
    let isActive: Bool
    let isGenerating: Bool
    let lockedAppsCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(buttonIcon)
                Text(buttonTitle)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
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
            .shadow(color: (isActive ? Color.antesGreen : Color.antesBlue).opacity(0.23), radius: 20, y: 12)
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
        .opacity(isGenerating ? 0.74 : 1)
        .accessibilityLabel(buttonTitle)
    }

    private var buttonIcon: String {
        if isGenerating { return "✨" }
        return isActive ? "✅" : "🔒"
    }

    private var buttonTitle: String {
        if isGenerating {
            return "Gerando ritual com IA..."
        }
        if isActive {
            return lockedAppsCount == 0 ? "Ritual ativo" : "Ritual ativo para apps bloqueados"
        }
        return "Ativar ritual e bloquear apps"
    }
}

private struct ScheduleRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("□")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color.antesMuted)
                .frame(width: 28)

            Text("Programação: todos os dias, o dia todo")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.antesMuted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button("Alterar") {}
                .font(.system(size: 15, weight: .bold))
        }
    }
}

private struct AppFooterView: View {
    var body: some View {
        Text("Criado com cuidado pela equipe Antes. ❤️")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.antesMuted)
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.antesStroke)
                    .frame(height: 1)
            }
    }
}

private struct ProfilePanel: View {
    private let items: [ProfileMenuItem] = [
        .init(title: "Relatórios", subtitle: "Tempo recuperado e progresso", systemImage: "chart.bar.fill"),
        .init(title: "Descobrir", subtitle: "Novos rituais e hábitos", systemImage: "sparkles"),
        .init(title: "Ajustes", subtitle: "Apps, horários e permissões", systemImage: "gearshape.fill")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image("ProfileAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Romeu")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.antesInk)
                    Text("Sequência ativa: 7 dias")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.antesMuted)
                }
            }
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.antesStroke)
                    .frame(height: 1)
            }

            VStack(spacing: 4) {
                ForEach(items) { item in
                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Image(systemName: item.systemImage)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.antesBlue)
                                .frame(width: 34, height: 34)
                                .background(Color.antesSoftSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.antesInk)
                                Text(item.subtitle)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.antesMuted)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: Color(red: 0.078, green: 0.122, blue: 0.220).opacity(0.12), radius: 21, y: 18)
    }
}

private struct ProfileMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
}

private enum HabitSuggestion: String, CaseIterable, Identifiable {
    case scripture
    case gratitude
    case water
    case quiz
    case fitness

    static let primaryCases: [HabitSuggestion] = [.scripture, .gratitude, .water, .quiz]

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

    var emoji: String {
        switch self {
        case .scripture: "📖"
        case .gratitude: "❤️"
        case .water: "💧"
        case .quiz: "🎓"
        case .fitness: "💪"
        }
    }

    var tint: Color {
        switch self {
        case .scripture: Color(red: 0.000, green: 0.357, blue: 1.000)
        case .gratitude: Color(red: 0.980, green: 0.180, blue: 0.360)
        case .water: Color(red: 0.000, green: 0.600, blue: 0.900)
        case .quiz: Color(red: 0.950, green: 0.670, blue: 0.070)
        case .fitness: Color.antesGreen
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
    let symbolSize: CGFloat
    let palette: AppPalette
    var isLocked: Bool

    static let samples = [
        LockedApp(name: "TikTok", systemImage: "music.note", symbolSize: 28, palette: .blackWhite, isLocked: true),
        LockedApp(name: "Instagram", systemImage: "camera.fill", symbolSize: 26, palette: .instagram, isLocked: true),
        LockedApp(name: "YouTube", systemImage: "play.fill", symbolSize: 28, palette: .youtube, isLocked: true),
        LockedApp(name: "X", systemImage: "xmark", symbolSize: 26, palette: .blackWhite, isLocked: true),
        LockedApp(name: "Discord", systemImage: "gamecontroller.fill", symbolSize: 25, palette: .discord, isLocked: true)
    ]
}

private struct AppPalette {
    let background: Color
    let foreground: Color
    var stroke: Color = .black.opacity(0.06)
    var strokeWidth: CGFloat = 1
    var shadowOpacity: Double = 0

    static let blackWhite = AppPalette(background: Color(red: 0.012, green: 0.016, blue: 0.027), foreground: .white)
    static let instagram = AppPalette(background: Color(red: 0.953, green: 0.184, blue: 0.455), foreground: .white)
    static let discord = AppPalette(background: Color(red: 0.345, green: 0.396, blue: 0.949), foreground: .white)
    static let youtube = AppPalette(
        background: .white,
        foreground: .red,
        stroke: Color(red: 0.847, green: 0.871, blue: 0.918),
        strokeWidth: 2,
        shadowOpacity: 0.08
    )
}

private extension AIRitual {
    static func localPreview(for habit: String) -> AIRitual {
        let lower = habit.localizedLowercase

        if lower.contains("gratid") || lower.contains("grato") || lower.contains("grata") {
            return AIRitual(
                title: "Gratidão antes do app",
                category: "Journaling",
                durationMinutes: 3,
                unlockMinutes: 15,
                summary: "3 coisas concretas",
                steps: [
                    .init(title: "Respire", detail: "Faça uma pausa curta.", kind: "timer", target: "20s"),
                    .init(title: "Escreva", detail: "Liste 3 gratidões específicas.", kind: "count", target: "3"),
                    .init(title: "Conclua", detail: "Leia sua lista uma vez.", kind: "done", target: "OK")
                ],
                completionAction: "Liberar apps"
            )
        }

        return AIRitual(
            title: "Flexões antes do app",
            category: "Força",
            durationMinutes: 2,
            unlockMinutes: 15,
            summary: "10 flexões completas",
            steps: [
                .init(title: "Execução", detail: "10 flexões completas", kind: "count", target: "0/10"),
                .init(title: "Descanso", detail: "30 segundos", kind: "timer", target: "00:30"),
                .init(title: "Conclusão", detail: "Marque como concluído", kind: "done", target: "")
            ],
            completionAction: "Liberar apps"
        )
    }
}

extension Color {
    static let antesBackground = Color(red: 0.986, green: 0.988, blue: 0.992)
    static let antesInk = Color(red: 0.035, green: 0.039, blue: 0.051)
    static let antesMuted = Color(red: 0.415, green: 0.427, blue: 0.486)
    static let antesStroke = Color(red: 0.825, green: 0.842, blue: 0.875)
    static let antesInputStroke = Color(red: 0.749, green: 0.773, blue: 0.824)
    static let antesSoftSurface = Color(red: 0.957, green: 0.964, blue: 0.974)
    static let antesBlue = Color(red: 0.000, green: 0.357, blue: 1.000)
    static let antesGreen = Color(red: 0.075, green: 0.690, blue: 0.337)
}

#Preview {
    ContentView()
}

#Preview("StatusRow") {
    VStack(spacing: 12) {
        StatusRow(
            title: "Antes Pro ativo",
            subtitle: "Bloqueios e rituais premium liberados.",
            systemImage: "checkmark.seal.fill",
            tint: .antesGreen
        )

        StatusRow(
            title: "Antes Pro necessário",
            subtitle: "Use o teste de 7 dias para ativar bloqueios reais.",
            systemImage: "seal",
            tint: .antesMuted,
            actionTitle: "Ver plano"
        ) {}

        StatusRow(
            title: "Programação",
            subtitle: "Todos os dias, o dia todo",
            systemImage: "calendar",
            tint: .antesBlue,
            actionTitle: "Alterar"
        ) {}
    }
    .padding(22)
    .background(Color.antesBackground)
}

private struct StatusRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.antesInk)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.antesMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 15, weight: .semibold))
            }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.antesStroke, lineWidth: 1)
        }
    }
}
