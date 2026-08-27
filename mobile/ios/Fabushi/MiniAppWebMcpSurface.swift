import SwiftUI
import WebKit

private let webMcpOriginHost = "fabushi.ombhrum.com"

struct MiniAppWebMcpSurface: View {
    let plugin: MarketplacePlugin

    @Environment(\.dismiss) private var dismiss
    @State private var status = "正在加载 WebMCP…"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button("返回") { dismiss() }
                    .accessibilityIdentifier("miniapp-webmcp-close")

                VStack(alignment: .leading, spacing: 2) {
                    Text(plugin.displayName).font(.headline)
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)

            MiniAppWebView(
                pluginId: plugin.pluginId,
                status: $status
            )
            .accessibilityIdentifier("miniapp-webmcp-webview")
        }
        .accessibilityIdentifier("miniapp-webmcp-surface")
    }
}

private struct MiniAppWebView: UIViewRepresentable {
    let pluginId: String
    @Binding var status: String

    func makeCoordinator() -> Coordinator {
        Coordinator(status: $status)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.isInspectable = false

        var components = URLComponents()
        components.scheme = "https"
        components.host = webMcpOriginHost
        components.path = "/miniapps/\(pluginId)/"
        guard let url = components.url else { return webView }
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.loadHTMLString("", baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding private var status: String

        init(status: Binding<String>) {
            _status = status
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
            status = "正在加载 WebMCP…"
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            let probe = """
            (() => {
              const tools = window.__fabushiWebMcp?.list?.() || [];
              return JSON.stringify({ ready: tools.length > 0, tools: tools.map((tool) => tool.name) });
            })()
            """
            webView.evaluateJavaScript(probe) { [weak self] value, _ in
                guard let self else { return }
                let result = value as? String ?? ""
                self.status = result.contains("\"ready\":true")
                    ? "WebMCP 已连接"
                    : "WebMCP 页面已打开"
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url,
                  url.scheme == "https",
                  url.host == webMcpOriginHost
            else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
