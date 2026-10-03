import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var history: HistoryStore
    @State private var query = ""
    @State private var filter: String = "All"
    @State private var showNewFolder = false
    @State private var folderName = ""

    private var filters: [String] { ["All", "Favorites"] + history.folders }

    private var results: [Transcript] {
        history.items.filter { t in
            let passFilter: Bool
            switch filter {
            case "All": passFilter = true
            case "Favorites": passFilter = t.isFavorite
            default: passFilter = t.folder == filter
            }
            guard passFilter else { return false }
            guard !query.isEmpty else { return true }
            return t.text.localizedCaseInsensitiveContains(query)
                || t.title.localizedCaseInsensitiveContains(query)
                || (t.summary ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters, id: \.self) { f in
                                Button { filter = f } label: {
                                    Text(f).font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 14).padding(.vertical, 7)
                                        .background(filter == f ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color(.tertiarySystemFill)))
                                        .foregroundStyle(filter == f ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if history.folders.contains(f) {
                                        Button(role: .destructive) {
                                            history.deleteFolder(f)
                                            filter = "All"
                                        } label: { Label("Delete folder", systemImage: "trash") }
                                    }
                                }
                            }
                            Button { showNewFolder = true } label: {
                                Image(systemName: "folder.badge.plus")
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Color(.tertiarySystemFill)).clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                if results.isEmpty {
                    ContentUnavailableView(query.isEmpty ? "No transcriptions yet" : "No results",
                                           systemImage: query.isEmpty ? "waveform" : "magnifyingglass",
                                           description: Text(query.isEmpty ? "Share a voice message to Voice Reader or import an audio file." : "Try another word."))
                        .listRowBackground(Color.clear)
                } else {
                    Section("\(results.count) transcriptions") {
                        ForEach(results) { t in
                            NavigationLink(value: t.id) { TranscriptRow(t: t) }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { history.delete(t) } label: { Label("Delete", systemImage: "trash") }
                                }
                                .swipeActions(edge: .leading) {
                                    Button { history.toggleFavorite(t) } label: {
                                        Label("Favorite", systemImage: t.isFavorite ? "star.slash" : "star")
                                    }
                                    .tint(.yellow)
                                }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search in transcriptions")
            .navigationTitle("History")
            .navigationDestination(for: UUID.self) { TranscriptDetailView(id: $0) }
            .alert("New folder", isPresented: $showNewFolder) {
                TextField("Folder name", text: $folderName)
                Button("Create") { history.addFolder(folderName); folderName = "" }
                Button("Cancel", role: .cancel) { folderName = "" }
            }
        }
    }
}
