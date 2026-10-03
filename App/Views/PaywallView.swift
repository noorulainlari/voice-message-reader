import SwiftUI
import StoreKit

enum Links {
    static let site = "https://noorulainlari.github.io/voicereader-site"
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let supportEmail = "relnoorain@gmail.com"
}

struct PaywallView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = StoreManager()
    @State private var selected = ProductIDs.yearly
    @State private var showClose = false
    @State private var showPrivacy = false
    @State private var pulse = false

    private let fallback: [(id: String, title: String, price: String, period: String)] = [
        (ProductIDs.yearly, "Yearly", "$29.99", "year"),
        (ProductIDs.monthly, "Monthly", "$5.99", "month"),
        (ProductIDs.weekly, "Weekly", "$2.99", "week")
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    features
                    plans
                    cta
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())

            if showClose {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.25))
                        .clipShape(Circle())
                }
                .padding(.top, 14)
                .padding(.trailing, 16)
                .transition(.opacity)
            }
        }
        .task {
            await store.load()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { showClose = true }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
        }
        .alert("Notice", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(store.errorMessage ?? "") }
        .sheet(isPresented: $showPrivacy) { NavigationStack { PrivacyPolicyView() } }
        .interactiveDismissDisabled(!showClose)
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(.white.opacity(0.15)).frame(width: 130, height: 130)
                    .scaleEffect(pulse ? 1.08 : 0.95)
                Circle().fill(.white.opacity(0.2)).frame(width: 96, height: 96)
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.white)
                Image(systemName: "crown.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.yellow)
                    .offset(x: 34, y: -36)
            }
            Text("Voice Reader Pro")
                .font(.system(.largeTitle, design: .rounded).bold())
            Text("Read every voice message in seconds.\nNo limits.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .padding(.top, 50)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background(
            Theme.gradient
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .padding(.horizontal, -20)
                .ignoresSafeArea(edges: .top)
        )
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 14) {
            feature("infinity", "Unlimited transcriptions", "WhatsApp, Telegram, any audio or video")
            feature("sparkles", "AI summary & smart replies", "Get the point of long voice notes")
            feature("character.bubble", "Translate to any language", "Understand messages from anyone")
            feature("mic.fill", "Live transcription", "Record and see text as you speak")
            feature("arrow.down.doc.fill", "Export PDF, TXT & subtitles", "Save and share your text")
        }
        .card()
    }

    private func feature(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Theme.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.teal)
        }
    }

    private var plans: some View {
        VStack(spacing: 10) {
            ForEach(fallback, id: \.id) { item in
                planRow(item.id, title: item.title, fallbackPrice: item.price, fallbackPeriod: item.period)
            }
        }
    }

    private func planRow(_ id: String, title: String, fallbackPrice: String, fallbackPeriod: String) -> some View {
        let product = store.product(id)
        let isSel = selected == id
        let price = product?.displayPrice ?? fallbackPrice
        let period = product?.periodText ?? fallbackPeriod
        let trial = product?.freeTrialText ?? (id == ProductIDs.yearly ? "3-day free trial" : nil)

        return Button { withAnimation(.spring(duration: 0.25)) { selected = id } } label: {
            HStack(spacing: 14) {
                Image(systemName: isSel ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSel ? Theme.teal : Color(.tertiaryLabel))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    if let trial {
                        Text(trial).font(.caption.weight(.semibold)).foregroundStyle(Theme.teal)
                    } else {
                        Text("Cancel anytime").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(price)/\(period)").font(.subheadline.weight(.bold))
                    if let weekly = product?.weeklyPriceText {
                        Text(weekly).font(.caption).foregroundStyle(.secondary)
                    } else if id == ProductIDs.yearly {
                        Text("$0.58/week").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(.primary)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSel ? Theme.teal : Color.clear, lineWidth: 2.5)
            )
            .overlay(alignment: .topTrailing) {
                if id == ProductIDs.yearly {
                    Text("BEST VALUE · SAVE 80%")
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .offset(x: -14, y: -11)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var cta: some View {
        let product = store.product(selected)
        let hasTrial = product?.freeTrialText != nil || (product == nil && selected == ProductIDs.yearly)
        return VStack(spacing: 10) {
            Button {
                Task {
                    guard let product else {
                        store.errorMessage = "The App Store isn't available right now. Please check your connection and try again."
                        await store.load()
                        return
                    }
                    if await store.purchase(product) {
                        await state.refreshPro()
                        dismiss()
                    }
                }
            } label: {
                HStack {
                    if store.purchasing { ProgressView().tint(.white) }
                    Text(hasTrial ? "Start Free Trial" : "Continue")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .scaleEffect(pulse ? 1.02 : 1)
            .disabled(store.purchasing)

            Text(hasTrial
                 ? "3 days free, then \(product?.displayPrice ?? "$29.99")/year. Cancel anytime."
                 : "Auto-renews. Cancel anytime in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Label("No commitment · Cancel anytime", systemImage: "checkmark.shield.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.teal)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                Button("Restore") {
                    Task {
                        if await store.restore() {
                            await state.refreshPro()
                            dismiss()
                        }
                    }
                }
                Button("Terms") { UIApplication.shared.open(Links.terms) }
                Button("Privacy") { showPrivacy = true }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)

            Text("Payment is charged to your Apple ID at confirmation. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in your App Store account settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }
}
