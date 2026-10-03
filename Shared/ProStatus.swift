import Foundation
import StoreKit

enum ProductIDs {
    static let weekly = "com.noorulain.voicereader.pro.weekly"
    static let monthly = "com.noorulain.voicereader.pro.monthly"
    static let yearly = "com.noorulain.voicereader.pro.yearly"
    static let all = [weekly, monthly, yearly]
}

enum ProStatus {
    /// Re-checks active subscriptions and stores the result in the shared App Group.
    @discardableResult
    static func refresh() async -> Bool {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result,
               ProductIDs.all.contains(t.productID),
               t.revocationDate == nil,
               (t.expirationDate ?? .distantFuture) > Date() {
                active = true
            }
        }
        AppGroup.isPro = active
        return active
    }
}
