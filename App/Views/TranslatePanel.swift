import SwiftUI
#if canImport(Translation)
import Translation
#endif

/// iOS 18+: translate inside the app with Apple's on-device Translation.
@available(iOS 18.0, *)
struct TranslatePanel: View {
    let text: String
    var onDone: (String, String) -> Void   // (translation, language name)

    @Environment(\.dismiss) private var dismiss
    @State private var languages: [Locale.Language] = []
    @State private var target: Locale.Language?
    @State private var config: TranslationSession.Configuration?
    @State private var working = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let error {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
                Section("Translate to") {
                    ForEach(languages, id: \.self) { lang in
                        Button {
                            target = lang
                            start(lang)
                        } label: {
                            HStack {
                                Text(name(lang)).foregroundStyle(.primary)
                                Spacer()
                                if working && target == lang { ProgressView() }
                            }
                        }
                        .disabled(working)
                    }
                }
            }
            .navigationTitle("Translate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .task { await loadLanguages() }
            .translationTask(config) { session in
                await translate(with: session)
            }
        }
    }

    private func name(_ lang: Locale.Language) -> String {
        Locale.current.localizedString(forIdentifier: lang.minimalIdentifier) ?? lang.minimalIdentifier
    }

    private func loadLanguages() async {
        let all = await LanguageAvailability().supportedLanguages
        var seen = Set<String>()
        languages = all
            .filter { seen.insert(name($0)).inserted }
            .sorted { name($0) < name($1) }
    }

    private func start(_ lang: Locale.Language) {
        error = nil
        working = true
        if config?.target == lang {
            config?.invalidate()
        } else {
            config = TranslationSession.Configuration(source: nil, target: lang)
        }
    }

    private func translate(with session: TranslationSession) async {
        do {
            var parts: [String] = []
            for chunk in chunks(text) {
                let response = try await session.translate(chunk)
                parts.append(response.targetText)
            }
            working = false
            onDone(parts.joined(separator: " "), target.map(name) ?? "")
            dismiss()
        } catch {
            working = false
            self.error = "Translation failed. Make sure the language is downloaded and try again."
        }
    }

    /// Splits long text into ~800 character pieces at sentence boundaries.
    private func chunks(_ s: String) -> [String] {
        var out: [String] = []
        var current = ""
        s.enumerateSubstrings(in: s.startIndex..., options: .bySentences) { sub, _, _, _ in
            guard let sub else { return }
            if current.count + sub.count > 800, !current.isEmpty {
                out.append(current)
                current = ""
            }
            current += sub
        }
        if !current.isEmpty { out.append(current) }
        return out.isEmpty ? [s] : out
    }
}

/// iOS 17.4+: falls back to the system translation popover.
struct SystemTranslateModifier: ViewModifier {
    @Binding var isPresented: Bool
    let text: String

    func body(content: Content) -> some View {
        #if canImport(Translation)
        if #available(iOS 17.4, *) {
            content.translationPresentation(isPresented: $isPresented, text: text)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
