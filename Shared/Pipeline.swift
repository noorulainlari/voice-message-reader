import Foundation

enum PipelineError: LocalizedError {
    case noCredits
    var errorDescription: String? {
        "You've used your free transcriptions. Upgrade to Voice Reader Pro for unlimited transcriptions."
    }
}

/// Full flow: any file → m4a in App Group → text → saved Transcript.
enum Pipeline {
    static func run(input: URL, localeID: String, source: String) async throws -> Transcript {
        if !AppGroup.isPro { await ProStatus.refresh() }
        guard AppGroup.canTranscribe else { throw PipelineError.noCredits }

        let prepared = try await AudioPrep.prepare(input)
        let output = try await Transcriber.transcribe(url: prepared.url, localeID: localeID)

        let text = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = Transcript(
            title: text.isEmpty ? "No speech found" : Transcript.makeTitle(from: text),
            text: text.isEmpty ? "No speech was detected in this audio. Make sure the right language is selected." : text,
            segments: output.segments,
            localeID: localeID,
            duration: prepared.duration,
            source: source,
            audioFile: prepared.fileName
        )
        if !text.isEmpty { AppGroup.consumeCredit() }
        AppGroup.rememberLocale(localeID)
        return item
    }
}
