import AVFoundation
import Speech

/// Thread-safe holder for objects touched from the audio tap thread.
final class TapSink: @unchecked Sendable {
    private let lock = NSLock()
    private var _request: SFSpeechAudioBufferRecognitionRequest?
    private var _file: AVAudioFile?
    private(set) var level: Float = 0

    var request: SFSpeechAudioBufferRecognitionRequest? {
        get { lock.lock(); defer { lock.unlock() }; return _request }
        set { lock.lock(); _request = newValue; lock.unlock() }
    }

    var file: AVAudioFile? {
        get { lock.lock(); defer { lock.unlock() }; return _file }
        set { lock.lock(); _file = newValue; lock.unlock() }
    }

    func handle(_ buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
        try? file?.write(from: buffer)
        if let data = buffer.floatChannelData?[0] {
            let n = Int(buffer.frameLength)
            var sum: Float = 0
            for i in stride(from: 0, to: n, by: 8) { sum += abs(data[i]) }
            let avg = n > 0 ? sum / Float(max(n / 8, 1)) : 0
            lock.lock(); level = min(1, avg * 12); lock.unlock()
        }
    }
}

@MainActor
final class LiveTranscriber: ObservableObject {
    @Published var committed = ""
    @Published var partial = ""
    @Published var isRunning = false
    @Published var elapsed: Double = 0
    @Published var level: Float = 0
    @Published var error: String?

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    private let sink = TapSink()
    private var timer: Timer?
    private(set) var fileURL: URL?
    private var generation = 0

    var fullText: String {
        [committed, partial].filter { !$0.isEmpty }.joined(separator: " ")
    }

    func start(localeID: String) async {
        error = nil
        guard await Transcriber.requestAuthorization() else {
            error = TranscriberError.notAuthorized.localizedDescription
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            error = "Microphone access is off. Turn it on in Settings › Voice Reader."
            return
        }
        guard let rec = SFSpeechRecognizer(locale: Locale(identifier: localeID)), rec.isAvailable else {
            error = TranscriberError.languageUnavailable.localizedDescription
            return
        }
        recognizer = rec

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("rec-\(UUID().uuidString).caf")
            sink.file = try AVAudioFile(forWriting: url, settings: format.settings)
            fileURL = url

            startRequest()
            let sink = self.sink
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                sink.handle(buffer)
            }
            engine.prepare()
            try engine.start()

            committed = ""
            partial = ""
            elapsed = 0
            isRunning = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.elapsed += 0.1
                    self.level = self.sink.level
                }
            }
        } catch {
            self.error = "Could not start recording: \(error.localizedDescription)"
            cleanup()
        }
    }

    private func startRequest() {
        guard let recognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.addsPunctuation = true
        sink.request = request
        generation += 1
        let gen = generation

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                guard let self, gen == self.generation else { return }
                if let text { self.partial = text }
                if isFinal || failed {
                    self.commit()
                    // Server recognition stops after ~1 minute: keep going with a fresh request.
                    if self.isRunning { self.startRequest() }
                }
            }
        }
    }

    private func commit() {
        let p = partial.trimmingCharacters(in: .whitespacesAndNewlines)
        if !p.isEmpty { committed = committed.isEmpty ? p : committed + " " + p }
        partial = ""
    }

    /// Stops recording and returns the final text and recorded audio file.
    func stop() -> (text: String, url: URL?) {
        isRunning = false
        sink.request?.endAudio()
        commit()
        cleanup()
        return (committed, fileURL)
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        task?.cancel()
        task = nil
        generation += 1
        sink.request = nil
        sink.file = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
