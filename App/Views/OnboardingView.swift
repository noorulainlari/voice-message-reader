import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var page = 0

    var body: some View {
        VStack {
            TabView(selection: $page) {
                pageView(icon: "text.bubble.fill",
                         title: "Read voice messages",
                         text: "No time to listen? Turn voice notes from WhatsApp, Telegram and more into text in seconds.")
                    .tag(0)
                pageView(icon: "square.and.arrow.up.fill",
                         title: "Share › Voice Reader",
                         text: "Hold a voice message, tap Forward › Share and pick Voice Reader. The text appears right in the share sheet.")
                    .tag(1)
                pageView(icon: "sparkles",
                         title: "Summaries, translation & more",
                         text: "Get a quick summary, translate into another language, record live and export as PDF or subtitles.")
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page < 2 ? "Continue" : "Get Started") {
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    Task {
                        _ = await Transcriber.requestAuthorization()
                        state.onboarded = true
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        if !state.isPro { state.showPaywall = true }
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(Theme.teal)
            UIPageControl.appearance().pageIndicatorTintColor = UIColor.systemGray4
        }
    }

    private func pageView(icon: String, title: String, text: String) -> some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(Theme.gradient)
                    .frame(width: 150, height: 150)
                Image(systemName: icon).font(.system(size: 64)).foregroundStyle(.white)
            }
            Text(title).font(.title.bold()).multilineTextAlignment(.center)
            Text(text).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
}
