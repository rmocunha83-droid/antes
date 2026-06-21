import Foundation
import StoreKit

enum AntesProductID {
    static let yearly = "com.romeucunha.Antes.pro.yearly"
    static let monthly = "com.romeucunha.Antes.pro.monthly"
    static let all = [yearly, monthly]
}

@MainActor
final class SubscriptionStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    #if DEBUG
    @Published var developerUnlockEnabled = false
    #endif

    private var updatesTask: Task<Void, Never>?

    var hasProAccess: Bool {
        #if DEBUG
        if developerUnlockEnabled { return true }
        #endif
        return !purchasedProductIDs.isEmpty
    }

    var yearlyProduct: Product? {
        products.first { $0.id == AntesProductID.yearly }
    }

    var monthlyProduct: Product? {
        products.first { $0.id == AntesProductID.monthly }
    }

    var sortedProducts: [Product] {
        products.sorted { lhs, rhs in
            if lhs.id == AntesProductID.yearly { return true }
            if rhs.id == AntesProductID.yearly { return false }
            return lhs.price < rhs.price
        }
    }

    func start() async {
        guard updatesTask == nil else { return }

        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Não consegui validar uma atualização de compra."
                    }
                }
            }
        }

        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            products = try await Product.products(for: AntesProductID.all)
            if products.isEmpty {
                errorMessage = "Produtos de assinatura ainda não apareceram. Configure-os no App Store Connect ou use o desbloqueio de teste."
            }
        } catch {
            errorMessage = "Não consegui carregar os planos da App Store."
        }

        isLoading = false
    }

    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Compra não concluída. Tente novamente."
        }

        isLoading = false
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = "Não consegui restaurar compras agora."
        }

        isLoading = false
    }

    func refreshEntitlements() async {
        var activeProductIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  AntesProductID.all.contains(transaction.productID),
                  transaction.revocationDate == nil else {
                continue
            }
            activeProductIDs.insert(transaction.productID)
        }

        purchasedProductIDs = activeProductIDs
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreError.failedVerification
        }
    }
}

private enum StoreError: Error {
    case failedVerification
}
