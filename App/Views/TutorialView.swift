import SwiftUI

/// Animated step-by-step guide showing how to send a voice message to Voice Reader.
struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var app: ChatStyle = .whatsapp
    @State private var page = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("App", selection: $app) {
                    ForEach(ChatStyle.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 6)
                .onChange(of: app) { _, _ in withAnimation { page = 0 } }

                TabView(selection: $page) {
                    ForEach(0..<5, id: \.self) { i in
                        TutorialStep(app: app, step: i, active: page == i).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color(.systemGray4)))
                            .frame(width: i == page ? 26 : 8, height: 8)
                    }
                }
                .animation(.spring(duration: 0.3), value: page)
                .padding(.bottom, 14)

                Button(page < 4 ? "Next" : "Got it!") {
                    if page < 4 { withAnimation { page += 1 } } else { dismiss() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("How it works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

enum ChatStyle: String, CaseIterable, Identifiable {
    case whatsapp, telegram
    var id: String { rawValue }
    var name: String { self == .whatsapp ? "WhatsApp" : "Telegram" }
    var outgoing: Color { self == .whatsapp ? Color(red: 0.85, green: 0.98, blue: 0.82) : Color(red: 0.88, green: 0.95, blue: 1.0) }
    var wallpaper: Color { self == .whatsapp ? Color(red: 0.95, green: 0.93, blue: 0.89) : Color(red: 0.82, green: 0.89, blue: 0.80) }
    var accent: Color { self == .whatsapp ? Color(red: 0.05, green: 0.6, blue: 0.35) : Color(red: 0.16, green: 0.55, blue: 0.9) }
    var menuAction: String { self == .whatsapp ? "Forward" : "Select" }

    func title(_ step: Int) -> String {
        switch step {
        case 0: return "Press & hold the voice message"
        case 1: return "Tap \u{201C}\(menuAction)\u{201D}"
        case 2: return "Tap the Share button"
        case 3: return "Choose \u{201C}Transcribe\u{201D}"
        default: return "Done! Read it instantly"
        }
    }

    func subtitle(_ step: Int) -> String {
        switch step {
        case 0: return "Open the chat in \(name) and long-press any voice note."
        case 1: return self == .whatsapp ? "A menu appears. Tap Forward." : "A menu appears. Tap Select."
        case 2: return "Tap the share icon at the bottom of the screen."
        case 3: return "Scroll down and tap Transcribe, or tap the Voice Reader icon."
        default: return "The text appears right away. Copy it, translate it or get a summary."
        }
    }
}

struct TutorialStep: View {
    let app: ChatStyle
    let step: Int
    let active: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text(app.title(step))
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text(app.subtitle(step))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            PhoneFrame {
                switch step {
                case 0: ChatMock(app: app, selecting: false)
                case 1: MenuMock(app: app)
                case 2: ChatMock(app: app, selecting: true)
                case 3: ShareSheetMock()
                default: ResultMock()
                }
            }
            .overlay { if step < 4 { TapPointer(position: pointerPosition, active: active) } }
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .padding(.top, 18)
    }

    /// Relative (0…1) position of the tap pointer inside the phone.
    private var pointerPosition: CGPoint {
        switch step {
        case 0: return CGPoint(x: 0.42, y: 0.78)
        case 1: return CGPoint(x: 0.45, y: 0.66)
        case 2: return CGPoint(x: 0.88, y: 0.93)
        default: return CGPoint(x: 0.6, y: 0.83)
        }
    }
}

// MARK: - Phone + pointer

struct PhoneFrame<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .environment(\.colorScheme, .light)
            .frame(width: 230, height: 440)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(alignment: .top) {
                Capsule().fill(.black).frame(width: 74, height: 20).padding(.top, 8)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .fill(Color(white: 0.12))
                    .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
            )
    }
}

struct TapPointer: View {
    let position: CGPoint
    let active: Bool
    @State private var tap = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .stroke(Theme.teal, lineWidth: 3)
                    .frame(width: 44, height: 44)
                    .scaleEffect(tap ? 1.4 : 0.6)
                    .opacity(tap ? 0 : 0.9)
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 3)
                    .offset(x: 16, y: tap ? 20 : 26)
                    .scaleEffect(tap ? 0.92 : 1)
            }
            .position(x: geo.size.width * position.x, y: geo.size.height * position.y)
        }
        .allowsHitTesting(false)
        .onAppear { animate() }
        .onChange(of: active) { _, _ in animate() }
    }

    private func animate() {
        tap = false
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: false)) { tap = true }
    }
}

// MARK: - Mock screens

private struct VoiceBubble: View {
    var outgoing: Bool
    var app: ChatStyle
    var duration: String
    var highlighted = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "play.fill").font(.system(size: 11)).foregroundStyle(.gray)
            HStack(spacing: 2) {
                ForEach(0..<16, id: \.self) { i in
                    Capsule().fill(outgoing ? app.accent.opacity(0.6) : Color.gray.opacity(0.6))
                        .frame(width: 2, height: CGFloat([6, 10, 14, 8, 12, 5, 9, 13, 7, 11, 6, 10, 8, 12, 5, 9][i]))
                }
            }
            Text(duration).font(.system(size: 8)).foregroundStyle(.gray)
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background(outgoing ? app.outgoing : .white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(highlighted ? Theme.teal : .clear, lineWidth: 2)
        )
        .frame(maxWidth: .infinity, alignment: outgoing ? .trailing : .leading)
    }
}

private struct ChatHeader: View {
    var app: ChatStyle
    var selecting: Bool
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(app.accent.opacity(0.35)).frame(width: 24, height: 24)
                .overlay(Text("S").font(.caption2.bold()).foregroundStyle(app.accent))
            Text("Sara").font(.system(size: 12, weight: .semibold))
            Spacer()
            if selecting { Text("Cancel").font(.system(size: 11, weight: .medium)).foregroundStyle(app.accent) }
            else { Image(systemName: "phone").font(.system(size: 11)).foregroundStyle(app.accent) }
        }
        .padding(.horizontal, 12).padding(.top, 34).padding(.bottom, 8)
        .background(.white)
    }
}

struct ChatMock: View {
    let app: ChatStyle
    let selecting: Bool

    var body: some View {
        VStack(spacing: 0) {
            ChatHeader(app: app, selecting: selecting)
            VStack(spacing: 8) {
                row(out: false, "0:12")
                row(out: true, "0:08")
                row(out: false, "0:21")
                row(out: true, "0:05")
                row(out: false, "0:34", highlighted: true)
            }
            .padding(10)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .background(app.wallpaper)
            HStack {
                if selecting {
                    Image(systemName: "arrowshape.turn.up.right").foregroundStyle(app.accent)
                    Spacer()
                    Text("1 Selected").font(.system(size: 11, weight: .medium))
                    Spacer()
                    Image(systemName: "square.and.arrow.up").foregroundStyle(app.accent)
                } else {
                    Image(systemName: "plus").foregroundStyle(app.accent)
                    Capsule().stroke(Color(.systemGray4)).frame(height: 22)
                    Image(systemName: "mic.fill").foregroundStyle(app.accent)
                }
            }
            .font(.system(size: 13))
            .padding(.horizontal, 12).padding(.vertical, 10)
            .padding(.bottom, 10)
            .background(.white)
        }
    }

    private func row(out: Bool, _ d: String, highlighted: Bool = false) -> some View {
        HStack(spacing: 6) {
            if selecting {
                Image(systemName: highlighted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(highlighted ? app.accent : .gray)
            }
            VoiceBubble(outgoing: out, app: app, duration: d, highlighted: highlighted && !selecting)
        }
    }
}

struct MenuMock: View {
    let app: ChatStyle

    var body: some View {
        ZStack {
            ChatMock(app: app, selecting: false).blur(radius: 6).overlay(Color.black.opacity(0.15))
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(["👍", "❤️", "😂", "😮", "🙏"], id: \.self) { Text($0).font(.system(size: 15)) }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.white).clipShape(Capsule())
                VoiceBubble(outgoing: false, app: app, duration: "0:34").frame(width: 170)
                VStack(spacing: 0) {
                    menuRow("Reply", "arrowshape.turn.up.left")
                    menuRow(app.menuAction, app == .whatsapp ? "arrowshape.turn.up.right" : "checkmark.circle", highlight: true)
                    menuRow("Copy", "doc.on.doc")
                    menuRow("Delete", "trash", destructive: true)
                }
                .background(.white.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(width: 170)
            }
            .padding(.top, 60)
        }
    }

    private func menuRow(_ t: String, _ icon: String, highlight: Bool = false, destructive: Bool = false) -> some View {
        HStack {
            Text(t).font(.system(size: 12, weight: highlight ? .semibold : .regular))
            Spacer()
            Image(systemName: icon).font(.system(size: 11))
        }
        .foregroundStyle(destructive ? .red : .primary)
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(highlight ? Theme.teal.opacity(0.18) : .clear)
    }
}

struct ShareSheetMock: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "waveform").font(.system(size: 12)).foregroundStyle(.white)
                    .frame(width: 28, height: 28).background(Color.blue.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Voice message.opus").font(.system(size: 11, weight: .semibold))
                    Text("Audio · 54 KB").font(.system(size: 9)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
            }
            .padding(.top, 36)

            HStack(spacing: 10) {
                appIcon("AirDrop", Color.blue, "dot.radiowaves.up.forward")
                appIcon("Messages", Color.green, "message.fill")
                appIcon("Mail", Color.blue, "envelope.fill")
                VStack(spacing: 4) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.gradient)
                        Image(systemName: "text.bubble.fill").foregroundStyle(.white).font(.system(size: 16))
                    }
                    .frame(width: 40, height: 40)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.teal, lineWidth: 2).padding(-3))
                    Text("Voice Reader").font(.system(size: 8, weight: .semibold))
                }
            }

            VStack(spacing: 0) {
                actionRow("Copy", "doc.on.doc")
                actionRow("Save to Files", "folder")
                actionRow("Transcribe", "text.bubble", highlight: true)
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Spacer()
        }
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
    }

    private func appIcon(_ name: String, _ color: Color, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(.white).font(.system(size: 16))
                .frame(width: 40, height: 40).background(color)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(name).font(.system(size: 8))
        }
    }

    private func actionRow(_ t: String, _ icon: String, highlight: Bool = false) -> some View {
        HStack {
            Text(t).font(.system(size: 12, weight: highlight ? .semibold : .regular))
            Spacer()
            Image(systemName: icon).font(.system(size: 12))
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(highlight ? Theme.teal.opacity(0.18) : .clear)
    }
}

struct ResultMock: View {
    @State private var reveal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Done").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.teal)
                Spacer()
                Label("English", systemImage: "globe").font(.system(size: 10)).foregroundStyle(Theme.teal)
            }
            .padding(.top, 36)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill").foregroundStyle(Theme.teal).font(.system(size: 20))
                    Capsule().fill(Color(.systemGray5)).frame(height: 4)
                    Text("1.5x").font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.teal.opacity(0.15)).clipShape(Capsule())
                }
                Text("Hi! I'm running 10 minutes late. Can you order me a coffee? See you soon!")
                    .font(.system(size: 12))
                    .opacity(reveal ? 1 : 0)
                    .offset(y: reveal ? 0 : 6)
            }
            .padding(10)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Label("Summary", systemImage: "sparkles").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.teal)
                Text("• Running 10 min late\n• Wants you to order a coffee").font(.system(size: 10))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(reveal ? 1 : 0)

            HStack(spacing: 6) {
                pill("Copy", "doc.on.doc")
                pill("Translate", "character.bubble")
                pill("Share", "square.and.arrow.up")
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .onAppear { withAnimation(.easeOut(duration: 0.8).delay(0.3)) { reveal = true } }
    }

    private func pill(_ t: String, _ icon: String) -> some View {
        Label(t, systemImage: icon)
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(.white).clipShape(Capsule())
    }
}
