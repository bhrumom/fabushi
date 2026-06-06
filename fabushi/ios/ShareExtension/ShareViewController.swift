import Social
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {
    private let appGroupIdentifier = "group.com.ombhrum.fabushi.share"
    private let sharedPayloadKey = "inboundSharePayload"
    private let hostAppURLScheme = "fabushi"

    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
        Task { @MainActor in
            let payload = await buildPayload()
            savePayload(payload)
            openHostApp()
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    override func configurationItems() -> [Any]! {
        return []
    }

    private func buildPayload() async -> [String: Any] {
        var textParts: [String] = []
        var url = ""
        var title = ""
        var mimeType = ""

        if let contentText = contentText?.trimmingCharacters(in: .whitespacesAndNewlines), !contentText.isEmpty {
            textParts.append(contentText)
            if title.isEmpty { title = contentText.components(separatedBy: .newlines).first ?? "" }
        }

        let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        for item in extensionItems {
            if let attributedTitle = item.attributedTitle?.string.trimmingCharacters(in: .whitespacesAndNewlines), !attributedTitle.isEmpty {
                title = attributedTitle
            }
            if let attributedContent = item.attributedContentText?.string.trimmingCharacters(in: .whitespacesAndNewlines), !attributedContent.isEmpty {
                textParts.append(attributedContent)
            }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil), let resolved = urlString(from: loaded) {
                        if url.isEmpty { url = resolved }
                        textParts.append(resolved)
                        mimeType = UTType.url.identifier
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil), let resolved = textString(from: loaded) {
                        textParts.append(resolved)
                        if mimeType.isEmpty { mimeType = UTType.plainText.identifier }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    if let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil), let resolved = textString(from: loaded) {
                        textParts.append(resolved)
                        if mimeType.isEmpty { mimeType = UTType.text.identifier }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    if let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil), let resolved = urlString(from: loaded) {
                        textParts.append(resolved)
                        if mimeType.isEmpty { mimeType = UTType.fileURL.identifier }
                    }
                }
            }
        }

        let combinedText = unique(textParts).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if url.isEmpty, let first = firstHttpURL(in: combinedText) {
            url = first
        }
        if title.isEmpty {
            title = url.isEmpty ? "外部分享" : url
        }

        return [
            "text": combinedText,
            "url": url,
            "title": title,
            "mimeType": mimeType,
            "sourcePackage": "iOS 分享面板",
            "receivedAt": String(Int(Date().timeIntervalSince1970 * 1000))
        ]
    }

    private func savePayload(_ payload: [String: Any]) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        defaults.set(payload, forKey: sharedPayloadKey)
        defaults.synchronize()
    }

    private func openHostApp() {
        guard let url = URL(string: "\(hostAppURLScheme)://share-extension") else { return }
        extensionContext?.open(url, completionHandler: nil)
    }

    private func urlString(from value: NSSecureCoding?) -> String? {
        if let url = value as? URL { return url.absoluteString }
        if let string = value as? String { return string.trimmingCharacters(in: .whitespacesAndNewlines) }
        return nil
    }

    private func textString(from value: NSSecureCoding?) -> String? {
        if let string = value as? String { return string.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let attributed = value as? NSAttributedString { return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let url = value as? URL { return url.absoluteString }
        return nil
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { raw in
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, !seen.contains(value) else { return nil }
            seen.insert(value)
            return value
        }
    }

    private func firstHttpURL(in value: String) -> String? {
        let pattern = #"https?://[^\s]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsRange = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, options: [], range: nsRange), let range = Range(match.range, in: value) else { return nil }
        return String(value[range]).trimmingCharacters(in: CharacterSet(charactersIn: "，。、,.))）]】>》"))
    }
}
