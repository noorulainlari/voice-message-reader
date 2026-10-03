import SwiftUI

struct RecordView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var history: HistoryStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var live = LiveTranscriber()
    @State private var saving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                LanguageButton(localeID: $state.localeID)
                    .disabled(live.isRunning)

                ScrollViewReader { proxy in
                    ScrollView {
                        Text(live.fullText.isEmpty ? (live.isRunning ? "Listening…" : "Tap the microphone and start speaking. Your words appear here as you talk.") : live.fullText)
                            .font(.title3)
                            .foregroundStyle(live.fullText.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id("bottom")
                    }
                    .onChange(of: live.fullText) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .card()

                if let error = live.error {
                    Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                }

                Text(live.elapsed.clockString)
                    .font(.system(.title, design: .rounded).monospacedDigit().bold())

                Button { toggle() } label: {
                    ZStack {
                        Circle()
                            .fill(Theme.teal.opacity(0.18))
                            .frame(width: 110 + CGFloat(live.level) * 40, height: 110 + CGFloat(live.level) * 40)
                            .animation(.easeOut(duration: 0.1), value: live.level)
                        Circle().fill(live.isRunning ? AnyShapeStyle(Color.red) : AnyShapeStyle(Theme.gradient))
                            .frame(width: 88, height: 88)
                        Image(systemName: live.isRunning ? "stop.fill" : "mic.fill")
                            .font(.system(size: 34)).foregroundStyle(.white)
                    }
                    .frame(height: 150)
                }
                .disabled(saving)

                Text(live.isRunning ? "Tap to stop and save" : "Tap to record")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Live Transcribe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        if live.isRunning { _ = live.stop() }
                        dismiss()
                    }
                }
            }
        }
    }

    private func toggle() {
        if live.isRunning {
            let result = live.stop()
            save(text: result.text, audio: result.url)
        } else {
            guard AppGroup.canTranscribe else {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { state.showPaywall = true }
                return
            }
            Task { await live.start(localeID: state.localeID) }
        }
    }

    private func save(text: String, audio: URL?) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        saving = true
        Task {
            var prepared: AudioPrep.Prepared?
            if let audio { prepared = try? await AudioPrep.prepare(audio) }
            let item = Transcript(title: Transcript.makeTitle(from: clean),
                                  text: clean,
                                  localeID: state.localeID,
                                  duration: prepared?.duration ?? live.elapsed,
                                  source: "Recording",
                                  audioFile: prepared?.fileName)
            history.add(item)
            AppGroup.consumeCredit()
            AppGroup.rememberLocale(state.localeID)
            saving = false
            dismiss()
            state.tab = 0
            state.openTranscriptID = item.id
        }
    }
}
