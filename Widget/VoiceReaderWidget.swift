import WidgetKit
import SwiftUI

struct Entry: TimelineEntry {
    let date: Date
    let latest: Transcript?
    let count: Int
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), latest: Transcript(title: "Meeting moved to 3pm", text: "Hey, just letting you know the meeting moved to 3pm tomorrow.", localeID: "en_US"), count: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .after(Date().addingTimeInterval(3600))))
    }

    private func current() -> Entry {
        let file = HistoryDisk.load()
        let latest = file.items.max { $0.createdAt < $1.createdAt }
        return Entry(date: Date(), latest: latest, count: file.items.count)
    }
}

private let teal = Color(red: 0.05, green: 0.65, blue: 0.58)
private let deep = Color(red: 0.04, green: 0.36, blue: 0.42)

struct WidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if family == .systemSmall { small } else { medium }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: [teal, deep], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "text.bubble.fill").font(.title2)
            Spacer()
            Text("Live\nTranscribe").font(.headline)
            Text("\(entry.count) saved").font(.caption2).opacity(0.85)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "voicereader://record"))
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Latest", systemImage: "waveform").font(.caption.bold()).opacity(0.85)
                if let t = entry.latest {
                    Text(t.text).font(.subheadline).lineLimit(4)
                } else {
                    Text("Share a voice message to Voice Reader to see it here.").font(.subheadline)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(entry.latest.flatMap { URL(string: "voicereader://open?id=\($0.id.uuidString)") })

            Link(destination: URL(string: "voicereader://record")!) {
                VStack(spacing: 6) {
                    Image(systemName: "mic.fill").font(.title2)
                    Text("Record").font(.caption.bold())
                }
                .frame(width: 70, height: 90)
                .background(.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .foregroundStyle(.white)
    }
}

@main
struct VoiceReaderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VoiceReaderWidget", provider: Provider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("Voice Reader")
        .description("See your latest transcription and start recording in one tap.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
