import Foundation
import AVFoundation
import SwiftOGG

enum AudioPrepError: LocalizedError {
    case unsupported
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupported: return "This file has no audio we can read. Try sharing a voice message, audio or video file."
        case .exportFailed(let m): return "Could not read the audio. \(m)"
        }
    }
}

/// Converts any shared/imported file (WhatsApp .opus, Telegram .ogg, m4a, mp3, wav, video…)
/// into an .m4a stored inside the App Group, ready for transcription and playback.
enum AudioPrep {
    struct Prepared {
        let url: URL
        let fileName: String
        let duration: Double
    }

    static func prepare(_ input: URL) async throws -> Prepared {
        let name = UUID().uuidString + ".m4a"
        let dest = AppGroup.audioFolder.appendingPathComponent(name)

        if isOgg(input) {
            do {
                try OGGConverter.convertOpusOGGToM4aFile(src: input, dest: dest)
            } catch {
                throw AudioPrepError.exportFailed("Opus/Ogg decoding failed.")
            }
        } else {
            try await exportAudio(from: input, to: dest)
        }

        let duration = await durationOf(dest)
        return Prepared(url: dest, fileName: name, duration: duration)
    }

    static func isOgg(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ["opus", "ogg", "oga"].contains(ext) { return true }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let head = (try? handle.read(upToCount: 4)) ?? Data()
        return head == Data("OggS".utf8)
    }

    static func durationOf(_ url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        if let d = try? await asset.load(.duration) {
            let s = CMTimeGetSeconds(d)
            return s.isFinite ? s : 0
        }
        return 0
    }

    private static func exportAudio(from input: URL, to dest: URL) async throws {
        let asset = AVURLAsset(url: input)
        let tracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
        guard !tracks.isEmpty else { throw AudioPrepError.unsupported }

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioPrepError.exportFailed("Export not available.")
        }
        try? FileManager.default.removeItem(at: dest)
        session.outputURL = dest
        session.outputFileType = .m4a

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { cont.resume() }
        }
        if session.status != .completed {
            throw AudioPrepError.exportFailed(session.error?.localizedDescription ?? "")
        }
    }

    /// Splits an audio file into chunks (used for server-based recognition, which has a ~1 minute limit).
    static func split(_ url: URL, chunkSeconds: Double) throws -> [(url: URL, offset: Double)] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let framesPerChunk = AVAudioFrameCount(chunkSeconds * sampleRate)
        var result: [(URL, Double)] = []
        var offsetFrames: AVAudioFramePosition = 0
        let tmp = FileManager.default.temporaryDirectory

        while offsetFrames < file.length {
            let remaining = AVAudioFrameCount(file.length - offsetFrames)
            let count = min(framesPerChunk, remaining)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else { break }
            file.framePosition = offsetFrames
            try file.read(into: buffer, frameCount: count)
            let out = tmp.appendingPathComponent("chunk-\(UUID().uuidString).caf")
            let writer = try AVAudioFile(forWriting: out, settings: format.settings,
                                         commonFormat: format.commonFormat, interleaved: format.isInterleaved)
            try writer.write(from: buffer)
            result.append((out, Double(offsetFrames) / sampleRate))
            offsetFrames += AVAudioFramePosition(count)
        }
        return result
    }
}
