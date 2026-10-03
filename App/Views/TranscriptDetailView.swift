import SwiftUI

struct TranscriptDetailView: View {
    let id: UUID
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var player = AudioPlayerModel()

    @State private var showTimeline = false
    @State private var copied = false
    @State private var summarizing = false
    @State private var replies: [String] = []
    @State private var loadingReplies = false
    @State private var showTranslate = false
    @State private var showSystemTranslate = false
    @State private var exportURL: URL?
    @State private var showRename = false
    @State private var newTitle = ""
    @State private var showRelanguage = false
    @State private var relanguageID = AppGroup.preferredLocaleID
    @State private var confirmDelete = false

    private var t: Transcript? { history.item(id) }

    var body: some View {
        Group {
            if let t {
                content(t)
            } else {
                ContentUnavailableView("Not found", systemImage: "doc.questionmark")
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { player.stop() }
    }

    private func content(_ t: Transcript) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(t)
                if t.audioURL != nil { playerCard }
                textCard(t)
                actionGrid(t)
                if let s = t.summary, !s.isEmpty { infoCard("Summary", "sparkles", s) }
                if let tr = t.translation, !tr.isEmpty {
                    infoCard("Translation" + (t.translationLanguage.map { " · \($0)" } ?? ""), "character.bubble", tr)
                }
                if !replies.isEmpty { repliesCard }
            }
            .padding()
        }
        .onAppear {
            player.load(t.audioURL)
            if UserDefaults.standard.bool(forKey: "autoplay"), player.available, !player.isPlaying { player.toggle() }
        }
        .toolbar { toolbar(t) }
        .sheet(item: $exportURL) { url in ShareSheet(items: [url]) }
        .sheet(isPresented: $showTranslate) {
            if #available(iOS 18.0, *) {
                TranslatePanel(text: t.text) { text, lang in
                    var c = t
                    c.translation = text
                    c.translationLanguage = lang
                    history.update(c)
                }
            }
        }
        .modifier(SystemTranslateModifier(isPresented: $showSystemTranslate, text: t.text))
        .sheet(isPresented: $showRelanguage) {
            LanguagePicker(localeID: $relanguageID)
        }
        .onChange(of: relanguageID) { _, newID in
            retranscribe(t, localeID: newID)
        }
        .alert("Rename", isPresented: $showRename) {
            TextField("Title", text: $newTitle)
            Button("Save") {
                var c = t
                c.title = newTitle.isEmpty ? t.title : newTitle
                history.update(c)
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Delete this transcription?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                player.stop()
                history.delete(t)
                dismiss()
            }
        }
    }

    private func header(_ t: Transcript) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t.title).font(.title3.bold())
            HStack(spacing: 12) {
                Label(t.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                Label(t.languageName, systemImage: "globe")
            }
            .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label("\(t.wordCount) words", systemImage: "text.word.spacing")
                Label(t.source, systemImage: "tray.and.arrow.down")
                if let f = t.folder { Label(f, systemImage: "folder") }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var playerCard: some View {
        HStack(spacing: 14) {
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 42)).foregroundStyle(Theme.teal)
            }
            VStack(spacing: 4) {
                Slider(value: Binding(get: { player.current }, set: { player.seek($0) }),
                       in: 0...max(player.duration, 0.1))
                HStack {
                    Text(player.current.clockString)
                    Spacer()
                    Text(player.duration.clockString)
                }
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            Button { player.cycleRate() } label: {
                Text(String(format: "%gx", player.rate))
                    .font(.subheadline.bold().monospacedDigit())
                    .frame(width: 50, height: 32)
                    .background(Theme.teal.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .card()
    }

    private func textCard(_ t: Transcript) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !t.segments.isEmpty {
                Picker("", selection: $showTimeline) {
                    Text("Text").tag(false)
                    Text("Timeline").tag(true)
                }
                .pickerStyle(.segmented)
            }
            if showTimeline {
                ForEach(Array(t.segments.enumerated()), id: \.offset) { _, s in
                    Button { player.seek(s.start) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Text(s.start.clockString)
                                .font(.caption.monospacedDigit()).foregroundStyle(Theme.teal)
                                .frame(width: 44, alignment: .leading)
                            Text(s.text).font(.body).foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text(t.text)
                    .font(.body)
                    .lineSpacing(3)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func actionGrid(_ t: Transcript) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 10) {
            action(copied ? "Copied" : "Copy", copied ? "checkmark" : "doc.on.doc") {
                UIPasteboard.general.string = t.text
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            }
            ShareLink(item: t.text) { actionLabel("Share", "square.and.arrow.up") }
            action(summarizing ? "Working…" : "Summary", "sparkles") { summarize(t) }
                .disabled(summarizing)
            action("Translate", "character.bubble") {
                if #available(iOS 18.0, *) { showTranslate = true } else { showSystemTranslate = true }
            }
            if AIHelper.appleIntelligenceAvailable {
                action(loadingReplies ? "Working…" : "Replies", "arrowshape.turn.up.left") { makeReplies(t) }
                    .disabled(loadingReplies)
            }
            Menu {
                ForEach(ExportFormat.allCases) { f in
                    Button(f.rawValue) { exportURL = Exporter.file(for: t, format: f) }
                }
            } label: { actionLabel("Export", "arrow.down.doc") }
        }
    }

    private func action(_ title: String, _ icon: String, run: @escaping () -> Void) -> some View {
        Button(action: run) { actionLabel(title, icon) }
    }

    private func actionLabel(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(Theme.teal)
            Text(title).font(.caption.weight(.medium)).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func infoCard(_ title: String, _ icon: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon).font(.headline).foregroundStyle(Theme.teal)
                Spacer()
                Button { UIPasteboard.general.string = text } label: { Image(systemName: "doc.on.doc") }
            }
            Text(text).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var repliesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Suggested replies", systemImage: "arrowshape.turn.up.left").font(.headline).foregroundStyle(Theme.teal)
            ForEach(replies, id: \.self) { r in
                HStack {
                    Text(r).font(.subheadline)
                    Spacer()
                    ShareLink(item: r) { Image(systemName: "paperplane.fill") }
                    Button { UIPasteboard.general.string = r } label: { Image(systemName: "doc.on.doc") }
                }
                .padding(10)
                .background(Theme.teal.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .card()
    }

    @ToolbarContentBuilder
    private func toolbar(_ t: Transcript) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { history.toggleFavorite(t) } label: {
                Image(systemName: t.isFavorite ? "star.fill" : "star")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { newTitle = t.title; showRename = true } label: { Label("Rename", systemImage: "pencil") }
                Menu {
                    Button("No folder") { history.move(t, to: nil) }
                    ForEach(history.folders, id: \.self) { f in
                        Button(f) { history.move(t, to: f) }
                    }
                } label: { Label("Move to folder", systemImage: "folder") }
                if t.audioURL != nil {
                    Button { relanguageID = t.localeID; showRelanguage = true } label: {
                        Label("Transcribe again in another language", systemImage: "globe")
                    }
                }
                Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
            } label: { Image(systemName: "ellipsis.circle") }
        }
    }

    // MARK: Actions

    private func summarize(_ t: Transcript) {
        summarizing = true
        Task {
            let s = await AIHelper.summarize(t.text)
            var c = t
            c.summary = s
            history.update(c)
            summarizing = false
        }
    }

    private func makeReplies(_ t: Transcript) {
        loadingReplies = true
        Task {
            replies = await AIHelper.smartReplies(to: t.text)
            loadingReplies = false
        }
    }

    private func retranscribe(_ t: Transcript, localeID: String) {
        guard localeID != t.localeID, let url = t.audioURL else { return }
        guard AppGroup.canTranscribe else { state.showPaywall = true; return }
        state.processing = true
        Task {
            do {
                let out = try await Transcriber.transcribe(url: url, localeID: localeID)
                var c = t
                c.text = out.text.isEmpty ? t.text : out.text
                c.segments = out.segments
                c.localeID = localeID
                c.title = Transcript.makeTitle(from: c.text)
                c.summary = nil
                c.translation = nil
                history.update(c)
                AppGroup.consumeCredit()
                AppGroup.rememberLocale(localeID)
            } catch {
                state.processingError = error.localizedDescription
            }
            state.processing = false
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
