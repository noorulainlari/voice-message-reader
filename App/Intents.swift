import AppIntents
import UIKit
import UniformTypeIdentifiers

struct TranscribeAudioIntent: AppIntent {
    static var title: LocalizedStringResource = "Transcribe Audio"
    static var description = IntentDescription("Turns a voice message, audio or video file into text.")

    @Parameter(title: "Audio File", supportedTypeIdentifiers: ["public.audio", "public.movie", "public.audiovisual-content", "public.data"])
    var file: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let ext = file.filename.split(separator: ".").last.map(String.init) ?? "audio"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
        if let src = file.fileURL {
            let access = src.startAccessingSecurityScopedResource()
            defer { if access { src.stopAccessingSecurityScopedResource() } }
            try FileManager.default.copyItem(at: src, to: url)
        } else {
            try file.data.write(to: url)
        }

        let item = try await Pipeline.run(input: url, localeID: AppGroup.preferredLocaleID, source: "Shortcut")
        HistoryDisk.append(item)
        return .result(value: item.text, dialog: IntentDialog(stringLiteral: String(item.text.prefix(500))))
    }
}

struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Live Transcription"
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "\(AppGroup.urlScheme)://record") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

struct VoiceReaderShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TranscribeAudioIntent(),
                    phrases: ["Transcribe audio with \(.applicationName)",
                              "Convert voice message with \(.applicationName)"],
                    shortTitle: "Transcribe Audio",
                    systemImageName: "waveform")
        AppShortcut(intent: StartRecordingIntent(),
                    phrases: ["Start live transcription in \(.applicationName)",
                              "Record with \(.applicationName)"],
                    shortTitle: "Live Transcribe",
                    systemImageName: "mic.fill")
    }
}
