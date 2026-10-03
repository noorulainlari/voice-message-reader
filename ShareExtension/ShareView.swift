import SwiftUI
import UIKit

@MainActor
final class ShareModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case working
        case done
        case failed(String)
        case needsApp(String)
        case needsPro
    }

    @Published var phase: Phase = .loading
    @Published var localeID: String = AppGroup.preferredLocaleID
    @Published var transcript: Transcript?
    @Published var summary: String?
    @Published var summarizing = false
    @Published var copied = false

    var close: () -> Void = {}
    var openApp: (URL) -> Void = { _ in }
    private var input: URL?

    func start(with url: URL) {
        input = url
        run()
    }

    func fail(_ message: String) { phase = .failed(message) }

    func run() {
        guard let input else { return }
        phase = .working
        summary = nil
        Task {
            do {
                let item = try await Pipeline.run(input: input, localeID: localeID, source: "Shared")
                HistoryDisk.append(item)
                transcript = item
                phase = .done
            } catch PipelineError.noCredits {
                phase = .needsPro
            } catch TranscriberError.notAuthorized {
                phase = .needsApp("Allow Speech Recognition once in the Voice Reader app, then share again.")
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func copy() {
        guard let text = transcript?.text else { return }
        UIPasteboard.general.string = text
        copied = true
        Task { try? await Task.sleep(nanoseconds: 1_500_000_000); copied = false }
    }

    func summarize() {
        guard let t = transcript else { return }
        summarizing = true
        Task {
            let s = await AIHelper.summarize(t.text)
            summary = s
            summarizing = false
            var file = HistoryDisk.load()
            if let idx = file.items.firstIndex(where: { $0.id == t.id }) {
                file.items[idx].summary = s
                HistoryDisk.save(file)
            }
        }
    }

    /// Saves the file into the shared inbox so the main app can process it.
    func sendToApp() {
        if let input {
            let dest = AppGroup.inboxFolder.appendingPathComponent(input.lastPathComponent)
            try? FileManager.default.copyItem(at: input, to: dest)
        }
        openApp(URL(string: "\(AppGroup.urlScheme)://inbox")!)
    }

    func openTranscript() {
        guard let t = transcript else { return }
        openApp(URL(string: "\(AppGroup.urlScheme)://open?id=\(t.id.uuidString)")!)
    }

    func openPaywall() {
        openApp(URL(string: "\(AppGroup.urlScheme)://pro")!)
    }
}

struct ShareView: View {
    @ObservedObject var model: ShareModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Voice Reader")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { model.close() }
                    }
                }
        }
        .tint(Theme.teal)
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading, .working:
            VStack(spacing: 20) {
                Spacer()
                WaveformView(animating: true)
                Text(model.phase == .loading ? "Opening audio…" : "Transcribing…")
                    .font(.title3.weight(.semibold))
                Text("Language: \(Transcriber.displayName(model.localeID))")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)

        case .done:
            if let t = model.transcript { resultView(t) }

        case .failed(let message):
            messageView(icon: "exclamationmark.triangle.fill", title: "Couldn't transcribe", message: message) {
                LanguageButton(localeID: $model.localeID)
                Button("Try again") { model.run() }.buttonStyle(PrimaryButtonStyle())
            }

        case .needsApp(let message):
            messageView(icon: "lock.open.fill", title: "One quick step", message: message) {
                Button("Open Voice Reader") { model.sendToApp() }.buttonStyle(PrimaryButtonStyle())
            }

        case .needsPro:
            messageView(icon: "crown.fill", title: "Free transcriptions used",
                        message: "Upgrade to Pro for unlimited voice message transcriptions, summaries and translations.") {
                Button("See Pro plans") { model.openPaywall() }.buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func resultView(_ t: Transcript) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    LanguageButton(localeID: Binding(
                        get: { model.localeID },
                        set: { model.localeID = $0; model.run() }))
                    Spacer()
                    Label(t.duration.clockString, systemImage: "waveform")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                Text(t.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()

                if let summary = model.summary {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Summary", systemImage: "sparkles").font(.headline).foregroundStyle(Theme.teal)
                        Text(summary).textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }

                HStack(spacing: 10) {
                    actionButton(model.copied ? "Copied" : "Copy", model.copied ? "checkmark" : "doc.on.doc") { model.copy() }
                    actionButton(model.summarizing ? "…" : "Summary", "sparkles") { model.summarize() }
                        .disabled(model.summarizing || model.summary != nil)
                    ShareLink(item: t.text) {
                        actionLabel("Share", "square.and.arrow.up")
                    }
                }

                Button("Open in Voice Reader") { model.openTranscript() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 4)

                if !AppGroup.isPro {
                    Text("\(AppGroup.freeLeft) free transcriptions left")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func actionButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { actionLabel(title, icon) }
    }

    private func actionLabel(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func messageView<Buttons: View>(icon: String, title: String, message: String,
                                            @ViewBuilder buttons: () -> Buttons) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon).font(.system(size: 44)).foregroundStyle(Theme.teal)
            Text(title).font(.title3.weight(.semibold))
            Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
            buttons()
            Spacer()
        }
        .padding(24)
    }
}
