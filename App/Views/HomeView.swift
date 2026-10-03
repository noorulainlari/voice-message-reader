import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct MovieFile: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { SentTransferredFile($0.url) } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "." + received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return MovieFile(url: dest)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var history: HistoryStore
    @State private var path: [UUID] = []
    @State private var showImporter = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showGuide = false

    static let importTypes: [UTType] = [
        .audio, .movie, .audiovisualContent, .mpeg4Audio, .mp3, .wav,
        UTType(importedAs: "org.xiph.opus"), UTType(importedAs: "org.xiph.ogg-audio")
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 18) {
                    if !state.isPro { proBanner }
                    hero
                    actions
                    quickApps
                    guideCard
                    recent
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Voice Reader")
            .navigationDestination(for: UUID.self) { id in TranscriptDetailView(id: id) }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: Self.importTypes) { result in
                if case .success(let url) = result { state.handle(url: url, history: history) }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let movie = try? await item.loadTransferable(type: MovieFile.self) {
                        state.transcribe(movie.url, source: "Video", history: history)
                    }
                    photoItem = nil
                }
            }
            .onChange(of: state.openTranscriptID) { _, id in
                guard let id else { return }
                path = [id]
                state.openTranscriptID = nil
            }
            .sheet(isPresented: $showGuide) { TutorialView() }
            .toolbar {
                if !state.isPro {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { state.showPaywall = true } label: {
                            Label("PRO", systemImage: "crown.fill")
                                .labelStyle(.titleAndIcon)
                                .font(.caption.weight(.heavy))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Theme.gradient)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.bubble.fill").font(.title)
                Spacer()
            }
            Text("Read voice messages\ninstead of listening")
                .font(.title2.bold())
            Text("Works with WhatsApp, Telegram, Signal, Voice Memos and any audio or video.")
                .font(.subheadline).opacity(0.9)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Audio language").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                LanguageButton(localeID: $state.localeID)
            }
            HStack(spacing: 12) {
                tile("Import File", "folder.fill") { showImporter = true }
                PhotosPicker(selection: $photoItem, matching: .videos) {
                    tileLabel("From Video", "video.fill")
                }
            }
            HStack(spacing: 12) {
                tile("Record Live", "mic.fill") { state.showRecorder = true }
                tile("How to Share", "square.and.arrow.up.fill") { showGuide = true }
            }
        }
    }

    private func tile(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { tileLabel(title, icon) }
    }

    private func tileLabel(_ title: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundStyle(Theme.teal)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .card()
    }

    private var guideCard: some View {
        Button { showGuide = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.title2).foregroundStyle(Theme.teal)
                VStack(alignment: .leading, spacing: 3) {
                    Text("From WhatsApp in 3 taps").font(.subheadline.bold()).foregroundStyle(.primary)
                    Text("Hold the voice message › Forward › Share › Transcribe")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .card()
        }
    }

    private var proBanner: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Free transcriptions: \(state.freeLeft)/\(AppGroup.freeLimit)")
                    .font(.subheadline.weight(.semibold))
                ProgressView(value: Double(state.freeLeft), total: Double(AppGroup.freeLimit))
                    .tint(Theme.teal)
            }
            Button { state.showPaywall = true } label: {
                VStack(spacing: 0) {
                    Image(systemName: "crown.fill").font(.caption)
                    Text("Upgrade").font(.subheadline.bold())
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Theme.gradient).foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .card()
    }

    private var quickApps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK ACTIONS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                quickApp("Open WhatsApp", "message.fill", Color(red: 0.15, green: 0.73, blue: 0.4), "whatsapp://")
                quickApp("Open Telegram", "paperplane.fill", Color(red: 0.16, green: 0.6, blue: 0.9), "tg://")
            }
        }
    }

    private func quickApp(_ title: String, _ icon: String, _ color: Color, _ scheme: String) -> some View {
        Button {
            if let url = URL(string: scheme) {
                UIApplication.shared.open(url) { ok in if !ok { showGuide = true } }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 28, height: 28).background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .card()
        }
    }

    @ViewBuilder
    private var recent: some View {
        if !history.items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Recent").font(.headline)
                    Spacer()
                    Button("See all") { state.tab = 1 }.font(.subheadline)
                }
                ForEach(history.items.prefix(5)) { t in
                    NavigationLink(value: t.id) { TranscriptRow(t: t).card() }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

struct TranscriptRow: View {
    let t: Transcript
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(t.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer()
                if t.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption) }
            }
            Text(t.text).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            HStack(spacing: 10) {
                Label(t.duration.clockString, systemImage: "waveform")
                Text(t.languageName)
                Spacer()
                Text(t.createdAt, style: .relative)
            }
            .font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
