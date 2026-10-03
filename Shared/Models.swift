import Foundation

struct Segment: Codable, Hashable {
    var start: Double
    var end: Double
    var text: String
}

struct Transcript: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var title: String
    var text: String
    var segments: [Segment] = []
    var localeID: String
    var duration: Double = 0
    var source: String = "Import"
    var audioFile: String?
    var summary: String?
    var translation: String?
    var translationLanguage: String?
    var folder: String?
    var isFavorite: Bool = false

    var audioURL: URL? {
        guard let audioFile else { return nil }
        let url = AppGroup.audioFolder.appendingPathComponent(audioFile)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    var wordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    var languageName: String {
        Locale.current.localizedString(forIdentifier: localeID) ?? localeID
    }

    static func makeTitle(from text: String) -> String {
        let words = text.split { $0.isWhitespace || $0.isNewline }.prefix(7)
        let title = words.joined(separator: " ")
        return title.isEmpty ? "Untitled" : title + (words.count == 7 ? "…" : "")
    }
}

struct HistoryFile: Codable {
    var items: [Transcript] = []
    var folders: [String] = []
}

enum HistoryDisk {
    static func load() -> HistoryFile {
        guard let data = try? Data(contentsOf: AppGroup.historyFile),
              let file = try? JSONDecoder().decode(HistoryFile.self, from: data) else {
            return HistoryFile()
        }
        return file
    }

    static func save(_ file: HistoryFile) {
        if let data = try? JSONEncoder().encode(file) {
            try? data.write(to: AppGroup.historyFile, options: .atomic)
        }
    }

    /// Used by the share extension: append one item without loading UI state.
    static func append(_ item: Transcript) {
        var file = load()
        file.items.insert(item, at: 0)
        save(file)
    }
}

extension Double {
    var clockString: String {
        let total = Int(self.rounded())
        let m = total / 60, s = total % 60
        if m >= 60 { return String(format: "%d:%02d:%02d", m / 60, m % 60, s) }
        return String(format: "%d:%02d", m, s)
    }
}
