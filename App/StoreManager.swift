import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var loading = false
    @Published var purchasing = false
    @Published var errorMessage: String?

    func load() async {
        guard products.isEmpty else { return }
        loading = true
        defer { loading = false }
        for attempt in 0..<3 {
            if let list = try? await Product.products(for: ProductIDs.all), !list.isEmpty {
                products = list.sorted { order($0.id) < order($1.id) }
                return
            }
            try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 1_000_000_000)
        }
    }

    private func order(_ id: String) -> Int {
        switch id {
        case ProductIDs.yearly: return 0
        case ProductIDs.monthly: return 1
        default: return 2
        }
    }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    /// Returns true when the purchase unlocked Pro.
    func purchase(_ product: Product) async -> Bool {
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                return await ProStatus.refresh()
            case .pending:
                errorMessage = "Your purchase is pending approval."
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restore() async -> Bool {
        try? await AppStore.sync()
        let pro = await ProStatus.refresh()
        if !pro { errorMessage = "No active subscription was found for this Apple ID." }
        return pro
    }
}

extension Product {
    var periodText: String {
        guard let p = subscription?.subscriptionPeriod else { return "" }
        switch p.unit {
        case .day: return p.value == 7 ? "week" : "\(p.value) days"
        case .week: return "week"
        case .month: return p.value == 1 ? "month" : "\(p.value) months"
        case .year: return "year"
        @unknown default: return ""
        }
    }

    var weeklyPriceText: String? {
        guard let p = subscription?.subscriptionPeriod else { return nil }
        let weeks: Decimal
        switch p.unit {
        case .year: weeks = 52
        case .month: weeks = Decimal(p.value) * 52 / 12
        default: return nil
        }
        let perWeek = price / weeks
        return perWeek.formatted(priceFormatStyle) + "/week"
    }

    var freeTrialText: String? {
        guard let offer = subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let unit: String
        switch offer.period.unit {
        case .day: unit = offer.period.value == 1 ? "day" : "days"
        case .week: unit = offer.period.value == 1 ? "week" : "weeks"
        case .month: unit = offer.period.value == 1 ? "month" : "months"
        case .year: unit = "year"
        @unknown default: unit = "days"
        }
        return "\(offer.period.value)-\(unit == "days" ? "day" : unit) free trial"
    }
}
