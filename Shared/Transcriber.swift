import Foundation
import AVFoundation
import Speech

struct TranscriptionOutput {
    var text: String
    var segments: [Segment]
    var engine: String
}

enum TranscriberError: LocalizedError {
    case notAuthorized
    case languageUnavailable
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition is turned off. Open the Voice Reader app and allow Speech Recognition (Settings › Voice Reader)."
        case .languageUnavailable:
            return "This language isn't available right now. Pick another language or check your internet connection."
        case .failed(let m):
            return m
        }
    }
}

enum Transcriber {

    // MARK: Languages

    static func allLocales() -> [Locale] {
        let set = SFSpeechRecognizer.supportedLocales()
        return set.sorted {
            (Locale.current.localizedString(forIdentifier: $0.identifier) ?? $0.identifier)
                < (Locale.current.localizedString(forIdentifier: $1.identifier) ?? $1.identifier)
        }
    }

    static func displayName(_ id: String) -> String {
        Locale.current.localizedString(forIdentifier: id) ?? id
    }

    // MARK: Authorization (only needed by the classic engine / live recording)

    static func requestAuthorization() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized { return true }
        if status == .denied || status == .restricted { return false }
        return await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
    }

    // MARK: Transcribe a file

    static func transcribe(url: URL, localeID: String) async throws -> TranscriptionOutput {
        let locale = Locale(identifier: localeID)

        if #available(iOS 26.0, *) {
            if let modern = try? await ModernEngine.transcribe(url: url, locale: locale) {
                return modern
            }
        }
        return try await ClassicEngine.transcribe(url: url, locale: locale)
    }
}

// MARK: - iOS 26 SpeechAnalyzer (new, more accurate, fully on-device)

@available(iOS 26.0, *)
enum ModernEngine {
    static func transcribe(url: URL, locale requested: Locale) async throws -> TranscriptionOutput? {
        guard SpeechTranscriber.isAvailable else { return nil }
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requested) else { return nil }

        let transcriber = SpeechTranscriber(locale: locale,
                                            transcriptionOptions: [],
                                            reportingOptions: [],
                                            attributeOptions: [.audioTimeRange])

        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])

        let collector = Task { () throws -> [Segment] in
            var segments: [Segment] = []
            for try await result in transcriber.results {
                let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                let start = result.range.start.seconds
                let end = CMTimeRangeGetEnd(result.range).seconds
                segments.append(Segment(start: start.isFinite ? start : 0,
                                        end: end.isFinite ? end : 0,
                                        text: text))
            }
            return segments
        }

        let file = try AVAudioFile(forReading: url)
        if let last = try await analyzer.analyzeSequence(from: file) {
            try await analyzer.finalizeAndFinish(through: last)
        } else {
            await analyzer.cancelAndFinishNow()
        }

        let segments = try await collector.value
        let text = segments.map(\.text).joined(separator: " ")
        return TranscriptionOutput(text: text, segments: segments, engine: "SpeechAnalyzer")
    }
}

// MARK: - Classic SFSpeechRecognizer (iOS 17+, 50+ languages)

enum ClassicEngine {
    static func transcribe(url: URL, locale: Locale) async throws -> TranscriptionOutput {
        guard await Transcriber.requestAuthorization() else { throw TranscriberError.notAuthorized }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw TranscriberError.languageUnavailable
        }

        if recognizer.supportsOnDeviceRecognition {
            let (text, segs) = try await recognize(url: url, recognizer: recognizer, onDevice: true, offset: 0)
            return TranscriptionOutput(text: text, segments: segs, engine: "On-device")
        }

        // Server recognition is limited to about one minute per request: split long audio.
        let duration = await AudioPrep.durationOf(url)
        if duration <= 55 {
            let (text, segs) = try await recognize(url: url, recognizer: recognizer, onDevice: false, offset: 0)
            return TranscriptionOutput(text: text, segments: segs, engine: "Apple")
        }

        let chunks = try AudioPrep.split(url, chunkSeconds: 50)
        var texts: [String] = []
        var allSegments: [Segment] = []
        for chunk in chunks {
            let (text, segs) = try await recognize(url: chunk.url, recognizer: recognizer, onDevice: false, offset: chunk.offset)
            if !text.isEmpty { texts.append(text) }
            allSegments.append(contentsOf: segs)
            try? FileManager.default.removeItem(at: chunk.url)
        }
        return TranscriptionOutput(text: texts.joined(separator: " "), segments: allSegments, engine: "Apple")
    }

    private static func recognize(url: URL, recognizer: SFSpeechRecognizer, onDevice: Bool, offset: Double) async throws -> (String, [Segment]) {
        try await withCheckedThrowingContinuation { cont in
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = onDevice
            request.addsPunctuation = true

            var finished = false
            let lock = NSLock()
            func finish(_ r: Result<(String, [Segment]), Error>) {
                lock.lock(); defer { lock.unlock() }
                guard !finished else { return }
                finished = true
                cont.resume(with: r)
            }

            _ = recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    let t = result.bestTranscription
                    finish(.success((t.formattedString, groupWords(t.segments, offset: offset))))
                } else if let error {
                    let ns = error as NSError
                    // 1110 = no speech detected → treat as empty text instead of failing.
                    if ns.code == 1110 || ns.code == 203 {
                        finish(.success(("", [])))
                    } else {
                        finish(.failure(TranscriberError.failed(error.localizedDescription)))
                    }
                }
            }
        }
    }

    /// Groups word-level timings into subtitle-sized lines.
    static func groupWords(_ words: [SFTranscriptionSegment], offset: Double) -> [Segment] {
        var out: [Segment] = []
        var current: [SFTranscriptionSegment] = []
        func flush() {
            guard let first = current.first, let last = current.last else { return }
            let text = current.map(\.substring).joined(separator: " ")
            out.append(Segment(start: offset + first.timestamp,
                               end: offset + last.timestamp + last.duration,
                               text: text))
            current.removeAll()
        }
        for w in words {
            current.append(w)
            let endsSentence = w.substring.last.map { ".!?".contains($0) } ?? false
            if current.count >= 9 || endsSentence { flush() }
        }
        flush()
        return out
    }
}
