import SwiftUI

struct LanguagePicker: View {
    @Binding var localeID: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private let all = Transcriber.allLocales()

    private var recents: [String] {
        AppGroup.recentLocaleIDs.filter { id in all.contains { $0.identifier == id } }
    }

    private var filtered: [Locale] {
        guard !query.isEmpty else { return all }
        return all.filter {
            Transcriber.displayName($0.identifier).localizedCaseInsensitiveContains(query)
                || $0.identifier.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty && !recents.isEmpty {
                    Section("Recent") {
                        ForEach(recents, id: \.self) { row($0) }
                    }
                }
                Section("All languages (\(all.count))") {
                    ForEach(filtered, id: \.identifier) { row($0.identifier) }
                }
            }
            .searchable(text: $query, prompt: "Search language")
            .navigationTitle("Language of the audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private func row(_ id: String) -> some View {
        Button {
            localeID = id
            AppGroup.preferredLocaleID = id
            dismiss()
        } label: {
            HStack {
                Text(Transcriber.displayName(id)).foregroundStyle(.primary)
                Spacer()
                if id == localeID { Image(systemName: "checkmark").foregroundStyle(Theme.teal) }
            }
        }
    }
}

struct LanguageButton: View {
    @Binding var localeID: String
    @State private var show = false

    var body: some View {
        Button { show = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text(Transcriber.displayName(localeID)).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2.bold())
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.teal.opacity(0.12))
            .foregroundStyle(Theme.teal)
            .clipShape(Capsule())
        }
        .sheet(isPresented: $show) { LanguagePicker(localeID: $localeID) }
    }
}
