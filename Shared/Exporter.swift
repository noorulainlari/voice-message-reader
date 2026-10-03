import UIKit

enum ExportFormat: String, CaseIterable, Identifiable {
    case txt = "Text (.txt)"
    case pdf = "PDF (.pdf)"
    case srt = "Subtitles (.srt)"
    var id: String { rawValue }
}

enum Exporter {
    static func file(for t: Transcript, format: ExportFormat) -> URL? {
        let base = safeName(t.title)
        let dir = FileManager.default.temporaryDirectory
        switch format {
        case .txt:
            let url = dir.appendingPathComponent(base + ".txt")
            try? fullText(t).write(to: url, atomically: true, encoding: .utf8)
            return url
        case .srt:
            let url = dir.appendingPathComponent(base + ".srt")
            try? srt(t).write(to: url, atomically: true, encoding: .utf8)
            return url
        case .pdf:
            let url = dir.appendingPathComponent(base + ".pdf")
            return pdf(t, to: url) ? url : nil
        }
    }

    static func fullText(_ t: Transcript) -> String {
        var s = t.title + "\n"
        s += DateFormatter.localizedString(from: t.createdAt, dateStyle: .medium, timeStyle: .short)
        s += " · \(t.languageName) · \(t.duration.clockString)\n\n"
        if let summary = t.summary, !summary.isEmpty { s += "Summary\n\(summary)\n\n" }
        s += t.text
        if let tr = t.translation, !tr.isEmpty { s += "\n\nTranslation\n\(tr)" }
        return s
    }

    static func srt(_ t: Transcript) -> String {
        let segs = t.segments.isEmpty ? [Segment(start: 0, end: max(t.duration, 1), text: t.text)] : t.segments
        return segs.enumerated().map { i, s in
            "\(i + 1)\n\(stamp(s.start)) --> \(stamp(max(s.end, s.start + 0.5)))\n\(s.text)\n"
        }.joined(separator: "\n")
    }

    private static func stamp(_ x: Double) -> String {
        let ms = Int((x * 1000).rounded())
        return String(format: "%02d:%02d:%02d,%03d", ms / 3_600_000, (ms / 60_000) % 60, (ms / 1000) % 60, ms % 1000)
    }

    private static func pdf(_ t: Transcript, to url: URL) -> Bool {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let formatter = UISimpleTextPrintFormatter(text: fullText(t))
        formatter.font = .systemFont(ofSize: 13)
        formatter.perPageContentInsets = UIEdgeInsets(top: 54, left: 54, bottom: 54, right: 54)

        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        renderer.setValue(NSValue(cgRect: page), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: page), forKey: "printableRect")

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, page, nil)
        for i in 0..<max(renderer.numberOfPages, 1) {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return data.write(to: url, atomically: true)
    }

    private static func safeName(_ s: String) -> String {
        let cleaned = s.components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted).joined()
        let trimmed = cleaned.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Transcript" : String(trimmed.prefix(40))
    }
}
