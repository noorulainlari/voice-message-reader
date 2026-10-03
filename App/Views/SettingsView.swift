import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var history: HistoryStore
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @AppStorage("lockEnabled") private var lockEnabled = false
    @AppStorage("autoCopy") private var autoCopy = false
    @State private var showGuide = false
    @State private var restoring = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if state.isPro {
                        Label("Voice Reader Pro is active", systemImage: "crown.fill")
                            .foregroundStyle(Theme.teal)
                        Button("Manage subscription") {
                            openURL(URL(string: "https://apps.apple.com/account/subscriptions")!)
                        }
                    } else {
                        Button { state.showPaywall = true } label: {
                            HStack {
                                Image(systemName: "crown.fill").foregroundStyle(.yellow)
                                VStack(alignment: .leading) {
                                    Text("Upgrade to Pro").font(.headline).foregroundStyle(.primary)
                                    Text("\(state.freeLeft) free transcriptions left").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Button(restoring ? "Restoring…" : "Restore purchases") {
                        restoring = true
                        Task {
                            try? await AppStore.sync()
                            await state.refreshPro()
                            restoring = false
                        }
                    }
                }

                Section("Transcription") {
                    HStack {
                        Text("Default language")
                        Spacer()
                        LanguageButton(localeID: $state.localeID)
                    }
                    Toggle("Copy text automatically", isOn: $autoCopy)
                    LabeledContent("AI summaries", value: AIHelper.appleIntelligenceAvailable ? "Apple Intelligence" : "Built-in")
                }

                Section("Privacy") {
                    Toggle("Lock with Face ID / passcode", isOn: $lockEnabled)
                        .onChange(of: lockEnabled) { _, on in if on { state.unlocked = true } }
                    Label("Audio is transcribed by Apple speech recognition, on your iPhone whenever your language supports it. We have no servers and never see your messages.",
                          systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Your stats") {
                    LabeledContent("Transcriptions", value: "\(history.items.count)")
                    LabeledContent("Minutes transcribed", value: "\(history.totalMinutes)")
                }

                Section("Help") {
                    Button("How to share from WhatsApp & Telegram") { showGuide = true }
                    Button("Contact support") {
                        openURL(URL(string: "mailto:\(Links.supportEmail)?subject=Voice%20Reader%20Support")!)
                    }
                    Button("Rate Voice Reader") { requestReview() }
                    Link("Privacy Policy", destination: Links.privacy)
                    Link("Terms of Use", destination: Links.terms)
                }

                Section {
                    Text("Voice Reader is not affiliated with WhatsApp, Meta, Telegram or Signal.")
                        .font(.caption2).foregroundStyle(.secondary)
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showGuide) { GuideView() }
        }
    }
}

struct GuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("WhatsApp") {
                    step(1, "Open the chat and press & hold the voice message.")
                    step(2, "Tap Forward, then tap the Share icon (bottom right).")
                    step(3, "Choose Voice Reader. The text appears right away.")
                }
                Section("Telegram") {
                    step(1, "Press & hold the voice message and tap Select.")
                    step(2, "Tap Share (or Forward › Share) and choose Voice Reader.")
                }
                Section("Voice Memos, Files & other apps") {
                    step(1, "Tap the ••• or Share button on the recording.")
                    step(2, "Choose Voice Reader.")
                }
                Section("Can't see Voice Reader?") {
                    step(1, "In the share sheet, scroll the app row to the end and tap More.")
                    step(2, "Tap Edit, add Voice Reader to Favorites and move it to the top.")
                }
            }
            .navigationTitle("How to share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)").font(.subheadline.bold()).foregroundStyle(.white)
                .frame(width: 26, height: 26).background(Theme.gradient).clipShape(Circle())
            Text(text).font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}
