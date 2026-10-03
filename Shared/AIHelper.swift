import Foundation
import NaturalLanguage
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Summaries and smart replies.
/// Uses Apple Intelligence (on-device) when available, otherwise a built-in key-sentence summarizer.
enum AIHelper {

    static var appleIntelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    static func summarize(_ text: String) async -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "" }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), appleIntelligenceAvailable {
            do {
                let session = LanguageModelSession(instructions: """
                You summarize voice messages. Reply in the same language as the message. \
                Give a one-line gist, then up to 4 short bullet points with key facts, dates, numbers and requests. \
                Do not add anything that is not in the message.
                """)
                let response = try await session.respond(to: "Voice message transcript:\n\(clean.prefix(12000))")
                let out = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !out.isEmpty { return out }
            } catch { }
        }
        #endif
        return extractiveSummary(clean)
    }

    static func smartReplies(to text: String) async -> [String] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), appleIntelligenceAvailable {
            do {
                let session = LanguageModelSession(instructions: """
                You suggest replies to a voice message someone received. Reply in the same language as the message. \
                Write exactly 3 short, natural reply options (max 20 words each), one per line, no numbering, no quotes.
                """)
                let response = try await session.respond(to: "Message:\n\(text.prefix(8000))")
                let lines = response.content
                    .split(whereSeparator: \.isNewline)
                    .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " -•*\"0123456789.)")) }
                    .filter { !$0.isEmpty }
                if !lines.isEmpty { return Array(lines.prefix(3)) }
            } catch { }
        }
        #endif
        return []
    }

    /// Picks the most informative sentences (works offline on every iPhone).
    static func extractiveSummary(_ text: String, maxSentences: Int = 3) -> String {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { sentences.append(s) }
            return true
        }
        if sentences.count <= maxSentences {
            return sentences.map { "• " + $0 }.joined(separator: "\n")
        }

        let wordTokenizer = NLTokenizer(unit: .word)
        var freq: [String: Int] = [:]
        func words(_ s: String) -> [String] {
            wordTokenizer.string = s
            var out: [String] = []
            wordTokenizer.enumerateTokens(in: s.startIndex..<s.endIndex) { r, _ in
                let w = s[r].lowercased()
                if w.count > 3 { out.append(w) }
                return true
            }
            return out
        }
        for s in sentences { for w in words(s) { freq[w, default: 0] += 1 } }

        let scored = sentences.enumerated().map { idx, s -> (Int, Double) in
            let ws = words(s)
            guard !ws.isEmpty else { return (idx, 0) }
            let score = Double(ws.reduce(0) { $0 + (freq[$1] ?? 0) }) / Double(ws.count)
            return (idx, score + (idx == 0 ? 0.5 : 0))
        }
        let best = scored.sorted { $0.1 > $1.1 }.prefix(maxSentences).map(\.0).sorted()
        return best.map { "• " + sentences[$0] }.joined(separator: "\n")
    }
}
