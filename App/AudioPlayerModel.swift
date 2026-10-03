import AVFoundation
import Combine

@MainActor
final class AudioPlayerModel: ObservableObject {
    @Published var isPlaying = false
    @Published var current: Double = 0
    @Published var duration: Double = 0
    @Published var rate: Float = 1.0

    private var player: AVAudioPlayer?
    private var timer: AnyCancellable?

    static let rates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    func load(_ url: URL?) {
        guard let url, player == nil else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.enableRate = true
        player?.prepareToPlay()
        duration = player?.duration ?? 0
    }

    var available: Bool { player != nil }

    func toggle() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            timer = nil
        } else {
            try? AVAudioSession.sharedInstance().setActive(true)
            player.rate = rate
            player.play()
            isPlaying = true
            timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect().sink { [weak self] _ in
                guard let self, let p = self.player else { return }
                self.current = p.currentTime
                if !p.isPlaying { self.isPlaying = false; self.timer = nil }
            }
        }
    }

    func seek(_ t: Double) {
        player?.currentTime = t
        current = t
        if !(player?.isPlaying ?? false) { toggle() }
    }

    func cycleRate() {
        let idx = Self.rates.firstIndex(of: rate) ?? 1
        rate = Self.rates[(idx + 1) % Self.rates.count]
        player?.rate = rate
    }

    func stop() {
        player?.stop()
        isPlaying = false
        timer = nil
    }
}
