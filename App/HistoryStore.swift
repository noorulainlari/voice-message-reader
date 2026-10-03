import Foundation
import WidgetKit

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [Transcript] = []
    @Published private(set) var folders: [String] = []

    init() { reload() }

    func reload() {
        let file = HistoryDisk.load()
        items = file.items.sorted { $0.createdAt > $1.createdAt }
        folders = file.folders
    }

    private func persist() {
        HistoryDisk.save(HistoryFile(items: items, folders: folders))
        WidgetCenter.shared.reloadAllTimelines()
    }

    func add(_ t: Transcript) {
        items.insert(t, at: 0)
        persist()
    }

    func update(_ t: Transcript) {
        guard let i = items.firstIndex(where: { $0.id == t.id }) else { return }
        items[i] = t
        persist()
    }

    func item(_ id: UUID) -> Transcript? { items.first { $0.id == id } }

    func delete(_ t: Transcript) {
        if let url = t.audioURL { try? FileManager.default.removeItem(at: url) }
        items.removeAll { $0.id == t.id }
        persist()
    }

    func toggleFavorite(_ t: Transcript) {
        var c = t
        c.isFavorite.toggle()
        update(c)
    }

    func addFolder(_ name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !folders.contains(n) else { return }
        folders.append(n)
        persist()
    }

    func deleteFolder(_ name: String) {
        folders.removeAll { $0 == name }
        for i in items.indices where items[i].folder == name { items[i].folder = nil }
        persist()
    }

    func move(_ t: Transcript, to folder: String?) {
        var c = t
        c.folder = folder
        update(c)
    }

    var totalMinutes: Int { Int(items.reduce(0) { $0 + $1.duration } / 60) }
}
