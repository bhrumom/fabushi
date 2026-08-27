import SwiftUI
import UIKit
import WebKit

private let webMcpOriginHost = "fabushi.ombhrum.com"
private let localWebMcpOriginHost = "miniapp.local.fabushi.invalid"
private let webMcpMessageHandler = "fabushiWebMcp"

struct MiniAppWebMcpSurface: View {
    let plugin: MarketplacePlugin
    let model: MarketplaceModel

    @Environment(\.dismiss) private var dismiss
    @State private var status = "正在解析本地 WebMCP…"
    @State private var localHtml: String?
    @State private var sourceResolved = false

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
                plugin: plugin,
                model: model,
                localHtml: localHtml,
                sourceResolved: sourceResolved,
                status: $status
            )
        }
        .accessibilityIdentifier("miniapp-webmcp-surface")
        .task(id: plugin.pluginId) {
            localHtml = await model.loadLocalMiniAppHtml(pluginId: plugin.pluginId)
            sourceResolved = true
            status = localHtml == nil ? "正在加载 Hosted WebMCP…" : "正在加载本地 WebMCP…"
        }
    }
}

private struct MiniAppWebView: UIViewRepresentable {
    let plugin: MarketplacePlugin
    let model: MarketplaceModel
    let localHtml: String?
    let sourceResolved: Bool
    @Binding var status: String

    func makeCoordinator() -> Coordinator {
        Coordinator(plugin: plugin, model: model, status: $status)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.userContentController.add(context.coordinator, name: webMcpMessageHandler)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.accessibilityIdentifier = "miniapp-webmcp-webview"
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.isInspectable = false
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard sourceResolved else { return }
        if let localHtml {
            let key = "local:\(plugin.pluginId)"
            guard context.coordinator.loadedSourceKey != key else { return }
            context.coordinator.loadedSourceKey = key
            let baseURL = URL(string: "https://\(localWebMcpOriginHost)/miniapps/\(plugin.pluginId)/")
            webView.loadHTMLString(injectLocalWebMcp(localHtml, plugin: plugin), baseURL: baseURL)
            return
        }

        let key = "hosted:\(plugin.pluginId)"
        guard context.coordinator.loadedSourceKey != key else { return }
        context.coordinator.loadedSourceKey = key
        var components = URLComponents()
        components.scheme = "https"
        components.host = webMcpOriginHost
        components.path = "/miniapps/\(plugin.pluginId)/"
        if let url = components.url {
            webView.load(URLRequest(url: url))
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: webMcpMessageHandler)
        webView.loadHTMLString("", baseURL: nil)
        coordinator.webView = nil
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let plugin: MarketplacePlugin
        let model: MarketplaceModel
        @Binding private var status: String
        weak var webView: WKWebView?
        var loadedSourceKey: String?
        private let toolByName: [String: MiniAppToolContract]

        init(plugin: MarketplacePlugin, model: MarketplaceModel, status: Binding<String>) {
            self.plugin = plugin
            self.model = model
            self.toolByName = Dictionary(uniqueKeysWithValues: plugin.tools.map { ($0.name, $0) })
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
            webView.evaluateJavaScript(probe) { [weak self, weak webView] value, _ in
                guard let self else { return }
                let result = value as? String ?? ""
                let local = webView?.url?.host == localWebMcpOriginHost
                if result.contains("\"ready\":true") {
                    self.status = local ? "本地 WebMCP 已连接" : "WebMCP 已连接"
                } else {
                    self.status = "WebMCP 页面已打开"
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url,
                  url.scheme == "https",
                  [webMcpOriginHost, localWebMcpOriginHost].contains(url.host ?? "")
            else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == webMcpMessageHandler,
                  let webView,
                  webView.url?.host == localWebMcpOriginHost,
                  let body = message.body as? [String: Any],
                  let requestId = body["requestId"] as? String,
                  let name = body["name"] as? String,
                  let tool = toolByName[name],
                  let input = body["input"] as? [String: Any]
            else { return }

            Task { @MainActor in
                do {
                    if tool.approval != "none" {
                        guard await requestApproval(tool) else {
                            resolve(webView: webView, requestId: requestId, payload: [
                                "ok": false,
                                "error": "用户取消了 WebMCP Tool 调用",
                            ])
                            return
                        }
                    }
                    let result = try await model.callMiniAppTool(
                        pluginId: plugin.pluginId,
                        name: name,
                        input: input
                    )
                    resolve(webView: webView, requestId: requestId, payload: [
                        "ok": true,
                        "result": result,
                    ])
                } catch {
                    resolve(webView: webView, requestId: requestId, payload: [
                        "ok": false,
                        "error": String(describing: error),
                    ])
                }
            }
        }

        private func requestApproval(_ tool: MiniAppToolContract) async -> Bool {
            await withCheckedContinuation { continuation in
                model.permissionRequest = PluginPermissionRequest(
                    pluginId: plugin.pluginId,
                    permissions: ["tool:\(tool.name)"],
                    resume: continuation
                )
            }
        }

        private func resolve(webView: WKWebView, requestId: String, payload: [String: Any]) {
            guard JSONSerialization.isValidJSONObject(payload),
                  let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8),
                  let requestData = try? JSONSerialization.data(withJSONObject: requestId),
                  let requestJson = String(data: requestData, encoding: .utf8)
            else { return }
            let script = "window.__fabushiWebMcpResolve?.(\(requestJson), \(json));"
            webView.evaluateJavaScript(script)
        }
    }
}

private func injectLocalWebMcp(_ html: String, plugin: MarketplacePlugin) -> String {
    let tools = plugin.tools.map { tool in
        [
            "name": tool.name,
            "description": tool.description,
            "approval": tool.approval,
            "inputSchema": tool.inputSchema,
        ] as [String: Any]
    }
    let data = (try? JSONSerialization.data(withJSONObject: tools)) ?? Data("[]".utf8)
    let toolsJson = String(data: data, encoding: .utf8) ?? "[]"
    let bridge = """
    <script>
    (() => {
      const definitions = \(toolsJson);
      const pending = new Map();
      let nextId = 1;
      window.__fabushiWebMcp = {
        list: () => definitions,
        call: (name, input = {}) => new Promise((resolve, reject) => {
          const requestId = String(nextId++);
          pending.set(requestId, { resolve, reject });
          window.webkit.messageHandlers.\(webMcpMessageHandler).postMessage({ requestId, name, input });
        })
      };
      window.__fabushiWebMcpResolve = (requestId, payload) => {
        const waiter = pending.get(String(requestId));
        if (!waiter) return;
        pending.delete(String(requestId));
        if (payload && payload.ok) waiter.resolve(payload.result);
        else waiter.reject(new Error(payload?.error || 'WebMCP call failed'));
      };
    })();
    </script>
    """
    if let range = html.range(of: "</head>", options: .caseInsensitive) {
        var copy = html
        copy.insert(contentsOf: bridge, at: range.lowerBound)
        return copy
    }
    return bridge + html
}
