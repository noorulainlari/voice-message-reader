import SwiftUI

struct RootView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var history: HistoryStore

    var body: some View {
        TabView(selection: $state.tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "waveform.circle.fill") }
                .tag(0)
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(1)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(2)
        }
        .overlay {
            if state.processing { ProcessingOverlay() }
        }
        .fullScreenCover(isPresented: $state.showPaywall) { PaywallView() }
        .sheet(isPresented: $state.showTutorial, onDismiss: {
            if !state.isPro {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { state.showPaywall = true }
            }
        }) { TutorialView() }
        .fullScreenCover(isPresented: $state.showRecorder) { RecordView() }
        .alert("Couldn't transcribe", isPresented: Binding(
            get: { state.processingError != nil },
            set: { if !$0 { state.processingError = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(state.processingError ?? "")
        }
    }
}

struct ProcessingOverlay: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                WaveformView(animating: true)
                Text("Transcribing…").font(.headline)
                Text(Transcriber.displayName(state.localeID))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(28)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}
