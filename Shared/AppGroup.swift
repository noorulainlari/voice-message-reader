import Foundation

enum AppGroup {
    static let id = "group.com.noorulain.voicereader"
    static let urlScheme = "voicereader"
    static let freeLimit = 3

    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }

    static var container: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
            return url
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var audioFolder: URL { folder("Audio") }
    static var inboxFolder: URL { folder("Inbox") }

    private static func folder(_ name: String) -> URL {
        let url = container.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var historyFile: URL { container.appendingPathComponent("transcripts.json") }

    // MARK: Pro & free credits (shared with extensions)

    static var isPro: Bool {
        get { defaults.bool(forKey: "isPro") }
        set { defaults.set(newValue, forKey: "isPro") }
    }

    static var freeUsed: Int {
        get { defaults.integer(forKey: "freeUsed") }
        set { defaults.set(newValue, forKey: "freeUsed") }
    }

    static var freeLeft: Int { max(0, freeLimit - freeUsed) }

    static var canTranscribe: Bool { isPro || freeLeft > 0 }

    static func consumeCredit() {
        if !isPro { freeUsed += 1 }
    }

    static var preferredLocaleID: String {
        get { defaults.string(forKey: "localeID") ?? Locale.current.identifier }
        set { defaults.set(newValue, forKey: "localeID") }
    }

    static var recentLocaleIDs: [String] {
        get { defaults.stringArray(forKey: "recentLocales") ?? [] }
        set { defaults.set(Array(newValue.prefix(6)), forKey: "recentLocales") }
    }

    static func rememberLocale(_ id: String) {
        var list = recentLocaleIDs.filter { $0 != id }
        list.insert(id, at: 0)
        recentLocaleIDs = list
        preferredLocaleID = id
    }
}
