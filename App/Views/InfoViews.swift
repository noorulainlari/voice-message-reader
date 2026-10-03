import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [(String, String)] = [
        ("Your messages stay yours", "Voice Reader has no servers, no accounts and no tracking. We never collect, store, sell or see your audio, your text or any personal data."),
        ("Audio and transcriptions", "Audio you share or record is turned into text by Apple's speech recognition. When your language supports it, everything happens on your iPhone. For some languages Apple may process the audio on its servers to complete the transcription, under Apple's Privacy Policy. The developer never receives it."),
        ("Stored on your device", "Transcriptions, summaries, translations and audio are saved only inside the app on your iPhone. Delete a transcription or the app to remove them."),
        ("Summaries and translation", "Summaries and suggested replies use Apple Intelligence on supported iPhones, or a built-in on-device method. Translation uses Apple's Translation framework."),
        ("Purchases", "Subscriptions are handled by Apple through the App Store. We never receive your payment details."),
        ("Analytics and ads", "The app contains no analytics, advertising or tracking SDKs."),
        ("Children", "Voice Reader is not directed to children under 13 and does not knowingly collect information from them."),
        ("Contact", "Questions about privacy? Email \(Links.supportEmail).")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill").font(.largeTitle).foregroundStyle(Theme.teal)
                    VStack(alignment: .leading) {
                        Text("Privacy Policy").font(.title2.bold())
                        Text("Last updated October 3, 2026").font(.caption).foregroundStyle(.secondary)
                    }
                }
                ForEach(sections, id: \.0) { s in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.0).font(.headline)
                        Text(s.1).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}

struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showTutorial = false
    @State private var expanded: String?

    private let faqs: [(String, String)] = [
        ("How do I transcribe a WhatsApp voice message?", "Press and hold the voice message, tap Forward, tap the Share button, then choose Transcribe (or the Voice Reader icon)."),
        ("I don't see Voice Reader in the share sheet", "Scroll to the bottom of the share sheet and tap Edit Actions, then add Transcribe to your Favorites. For the app row, scroll right, tap More and enable Voice Reader."),
        ("The text is wrong or empty", "Check that the audio language is correct. Open the transcription, tap ••• and choose Transcribe again in another language."),
        ("Does it work offline?", "Yes, for languages your iPhone supports on-device. Other languages need an internet connection."),
        ("How do I cancel my subscription?", "Open iPhone Settings › your name › Subscriptions › Voice Reader and tap Cancel. You keep Pro until the end of the period."),
        ("I paid but Pro isn't active", "Go to Settings in the app and tap Restore purchases, using the same Apple ID you bought with.")
    ]

    var body: some View {
        List {
            Section {
                Button { showTutorial = true } label: {
                    Label("Watch the step-by-step tutorial", systemImage: "play.rectangle.fill")
                }
            }
            Section("Frequently asked questions") {
                ForEach(faqs, id: \.0) { faq in
                    DisclosureGroup(isExpanded: Binding(
                        get: { expanded == faq.0 },
                        set: { expanded = $0 ? faq.0 : nil })) {
                        Text(faq.1).font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 4)
                    } label: {
                        Text(faq.0).font(.subheadline.weight(.medium))
                    }
                }
            }
            Section("Still need help?") {
                Button {
                    let subject = "Voice Reader Support".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "mailto:\(Links.supportEmail)?subject=\(subject)") { openURL(url) }
                } label: {
                    Label("Email support", systemImage: "envelope.fill")
                }
                Text("We usually reply within 48 hours.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .sheet(isPresented: $showTutorial) { TutorialView() }
    }
}
