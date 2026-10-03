import SwiftUI
import StoreKit

enum Links {
    static let site = "https://noorulainlari.github.io/voicereader-site"
    static let privacy = URL(string: site + "/privacy.html")!
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let support = URL(string: site + "/support.html")!
    static let supportEmail = "relnoorain@gmail.com"
}

struct PaywallView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(productIDs: ProductIDs.all) {
            VStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.yellow)
                Text("Voice Reader Pro")
                    .font(.largeTitle.bold())
                VStack(alignment: .leading, spacing: 10) {
                    feature("infinity", "Unlimited voice message transcriptions")
                    feature("sparkles", "AI summaries & smart replies")
                    feature("character.bubble", "Translate into any language")
                    feature("mic.fill", "Unlimited live recording")
                    feature("arrow.down.doc", "Export to PDF, TXT & subtitles")
                    feature("lock.shield", "Private: we never store or see your messages")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .containerBackground(Theme.gradient, for: .subscriptionStoreFullHeight)
        }
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .cancellation)
        .subscriptionStorePolicyDestination(url: Links.privacy, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: Links.terms, for: .termsOfService)
        .subscriptionStoreButtonLabel(.multiline)
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success(_)) = result {
                await state.refreshPro()
                if state.isPro { dismiss() }
            }
        }
        .tint(Theme.teal)
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 24)
            Text(text).font(.subheadline.weight(.medium))
        }
    }
}
