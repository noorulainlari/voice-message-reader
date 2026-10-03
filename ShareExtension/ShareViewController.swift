import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        model.close = { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        model.openApp = { [weak self] url in
            self?.openHostApp(url)
        }

        let host = UIHostingController(rootView: ShareView(model: model))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)

        Task { await loadAttachment() }
    }

    private func loadAttachment() async {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        for provider in providers {
            if let url = await Self.copyFile(from: provider) {
                await MainActor.run { model.start(with: url) }
                return
            }
        }
        await MainActor.run { model.fail("No audio was found in what you shared.") }
    }

    /// Copies the shared file into a temporary location we own.
    static func copyFile(from provider: NSItemProvider) async -> URL? {
        let types = provider.registeredTypeIdentifiers
        let preferred = types.first { id in
            guard let t = UTType(id) else { return false }
            return t.conforms(to: .audio) || t.conforms(to: .audiovisualContent) || t.conforms(to: .movie)
        } ?? types.first { $0 != UTType.fileURL.identifier && $0 != UTType.url.identifier } ?? types.first

        if let type = preferred, type != UTType.fileURL.identifier {
            let url: URL? = await withCheckedContinuation { cont in
                _ = provider.loadFileRepresentation(forTypeIdentifier: type) { tempURL, _ in
                    guard let tempURL else { cont.resume(returning: nil); return }
                    cont.resume(returning: copyToTemp(tempURL))
                }
            }
            if let url { return url }
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            return await withCheckedContinuation { cont in
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    if let url = item as? URL {
                        cont.resume(returning: copyToTemp(url))
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        cont.resume(returning: copyToTemp(url))
                    } else {
                        cont.resume(returning: nil)
                    }
                }
            }
        }
        return nil
    }

    private static func copyToTemp(_ url: URL) -> URL? {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.isEmpty ? "audio" : url.pathExtension
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            return dest
        } catch {
            return nil
        }
    }

    private func openHostApp(_ url: URL) {
        var responder: UIResponder? = self
        while let r = responder {
            if let app = r as? UIApplication {
                app.open(url, options: [:], completionHandler: nil)
                break
            }
            responder = r.next
        }
        extensionContext?.completeRequest(returningItems: nil)
    }
}
