import StoreKit
import SwiftUI

struct PaywallContext: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct PaywallView: View {
    @ObservedObject var subscriptionStore: SubscriptionStore
    let context: PaywallContext
    let closeAction: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Antes Pro")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(Color.antesInk)
                        Text(context.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.antesInk)
                        Text(context.message)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.antesMuted)
                            .lineSpacing(3)
                    }

                    VStack(spacing: 10) {
                        PaywallBenefitRow(systemImage: "checkmark.shield.fill", title: "Bloqueie qualquer app escolhido")
                        PaywallBenefitRow(systemImage: "sparkles", title: "Rituais gerados para seu objetivo")
                        PaywallBenefitRow(systemImage: "clock.arrow.circlepath", title: "Liberação temporária após concluir")
                    }

                    VStack(spacing: 12) {
                        if subscriptionStore.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                        }

                        ForEach(subscriptionStore.sortedProducts, id: \.id) { product in
                            PlanButton(
                                product: product,
                                isRecommended: product.id == AntesProductID.yearly
                            ) {
                                Task {
                                    await subscriptionStore.purchase(product)
                                    if subscriptionStore.hasProAccess {
                                        closeAction()
                                    }
                                }
                            }
                        }

                        if subscriptionStore.products.isEmpty, !subscriptionStore.isLoading {
                            MissingProductsView()
                        }
                    }

                    if let errorMessage = subscriptionStore.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.red)
                    }

                    Button("Restaurar compras") {
                        Task {
                            await subscriptionStore.restorePurchases()
                            if subscriptionStore.hasProAccess {
                                closeAction()
                            }
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)

                    #if DEBUG
                    Button("Liberar apenas neste build de teste") {
                        subscriptionStore.developerUnlockEnabled = true
                        closeAction()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.antesMuted)
                    .frame(maxWidth: .infinity)
                    #endif

                    Text("O teste grátis de 7 dias deve ser configurado no App Store Connect como oferta introdutória da assinatura. O cancelamento e a cobrança são gerenciados pela App Store.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.antesMuted)
                        .lineSpacing(2)
                }
                .padding(22)
            }
            .background(Color.antesBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar", action: closeAction)
                        .font(.system(size: 15, weight: .bold))
                }
            }
        }
        .task {
            await subscriptionStore.start()
        }
    }
}

private struct PlanButton: View {
    let product: Product
    let isRecommended: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.antesInk)
                        if isRecommended {
                            Text("Melhor valor")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.antesGreen, in: Capsule())
                        }
                    }
                    Text(product.displayPrice)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.antesMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.antesMuted)
            }
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isRecommended ? Color.antesGreen : Color.antesStroke, lineWidth: isRecommended ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var title: String {
        if product.id == AntesProductID.yearly {
            return "Anual"
        }
        if product.id == AntesProductID.monthly {
            return "Mensal"
        }
        return product.displayName
    }
}

private struct PaywallBenefitRow: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.antesGreen)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.antesInk)
        }
    }
}

private struct MissingProductsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planos ainda não configurados")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.antesInk)
            Text("Crie os produtos \(AntesProductID.yearly) e \(AntesProductID.monthly) no App Store Connect para vender na loja.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.antesMuted)
        }
        .padding(16)
        .background(Color.antesSoftSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
