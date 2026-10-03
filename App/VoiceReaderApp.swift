import SwiftUI
import LocalAuthentication

@main
struct VoiceReaderApp: App {
    @StateObject private var history = HistoryStore()
    @StateObject private var state = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                if state.onboarded {
                    RootView()
                } else {
                    OnboardingView()
                }
                if state.lockEnabled && !state.unlocked {
                    LockView()
                }
            }
            .environmentObject(history)
            .environmentObject(state)
            .tint(Theme.teal)
            .onOpenURL { state.handle(url: $0, history: history) }
            .task { await state.refreshPro() }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    history.reload()
                    state.isPro = AppGroup.isPro
                    if state.onboarded { state.processInbox(history: history) }
                case .background:
                    state.unlocked = false
                default: break
                }
            }
        }
    }
}

struct LockView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.fill").font(.system(size: 48)).foregroundStyle(.white)
            Text("Voice Reader is locked").font(.title3.bold()).foregroundStyle(.white)
            Button("Unlock") { authenticate() }
                .buttonStyle(.borderedProminent).tint(.white).foregroundStyle(Theme.deep)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.gradient.ignoresSafeArea())
        .onAppear { authenticate() }
    }

    private func authenticate() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            state.unlocked = true
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your transcriptions") { ok, _ in
            DispatchQueue.main.async { if ok { state.unlocked = true } }
        }
    }
}
