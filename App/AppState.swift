import SwiftUI
import StoreKit

@MainActor
final class AppState: ObservableObject {
    // Navigation
    @Published var tab: Int = 0
    @Published var openTranscriptID: UUID?
    @Published var showPaywall = false
    @Published var showRecorder = false
    @Published var showTutorial = false

    // Processing
    @Published var processing = false
    @Published var processingError: String?
    @Published var localeID: String = AppGroup.preferredLocaleID

    // Pro
    @Published var isPro: Bool = AppGroup.isPro

    // Privacy lock
    @AppStorage("lockEnabled") var lockEnabled = false
    @Published var unlocked = false

    @AppStorage("onboarded") var onboarded = false
    @AppStorage("autoCopy") var autoCopy = false

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let t) = update { await t.finish() }
                await self?.refreshPro()
            }
        }
    }

    func refreshPro() async {
        isPro = await ProStatus.refresh()
    }

    var freeLeft: Int { AppGroup.freeLeft }

    // MARK: Transcription

    func transcribe(_ url: URL, source: String, history: HistoryStore) {
        guard AppGroup.canTranscribe else {
            showPaywall = true
            return
        }
        processing = true
        processingError = nil
        Task {
            do {
                let item = try await Pipeline.run(input: url, localeID: localeID, source: source)
                history.add(item)
                processing = false
                if autoCopy { UIPasteboard.general.string = item.text }
                tab = 0
                openTranscriptID = item.id
            } catch PipelineError.noCredits {
                processing = false
                showPaywall = true
            } catch {
                processing = false
                processingError = error.localizedDescription
            }
        }
    }

    /// Files dropped into the shared inbox by the share extension.
    func processInbox(history: HistoryStore) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: AppGroup.inboxFolder, includingPropertiesForKeys: nil),
              let first = files.first else { return }
        let tmp = fm.temporaryDirectory.appendingPathComponent(first.lastPathComponent)
        try? fm.removeItem(at: tmp)
        try? fm.moveItem(at: first, to: tmp)
        for other in files.dropFirst() { try? fm.removeItem(at: other) }
        transcribe(tmp, source: "Shared", history: history)
    }

    // MARK: Deep links

    func handle(url: URL, history: HistoryStore) {
        if url.isFileURL {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + url.pathExtension)
            if (try? FileManager.default.copyItem(at: url, to: tmp)) != nil {
                transcribe(tmp, source: "Opened", history: history)
            }
            return
        }
        guard url.scheme == AppGroup.urlScheme else { return }
        history.reload()
        switch url.host {
        case "inbox":
            Task { _ = await Transcriber.requestAuthorization(); processInbox(history: history) }
        case "open":
            let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "id" }?.value
            if let id, let uuid = UUID(uuidString: id) {
                tab = 0
                openTranscriptID = uuid
            }
        case "pro":
            showPaywall = true
        case "record":
            showRecorder = true
        default:
            break
        }
    }
}
