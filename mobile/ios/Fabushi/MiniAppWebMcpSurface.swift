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

            if plugin.pluginId == GlobalDharmaCommerceModel.miniAppId {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: model.globalDharmaCommerce.accessAllowed ? "checkmark.seal.fill" : "lock.fill")
                            .foregroundStyle(model.globalDharmaCommerce.accessAllowed ? .green : .secondary)
                        Text(model.globalDharmaCommerce.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .accessibilityIdentifier("global-dharma-entitlement-status")

                    HStack(spacing: 10) {
                        if model.globalDharmaCommerce.accessAllowed {
                            Label("本地转经轮已买断", systemImage: "infinity")
                                .font(.subheadline.weight(.semibold))
                                .accessibilityIdentifier("global-dharma-entitlement-allowed")
                        } else {
                            Button("\(model.globalDharmaCommerce.lifetimePriceLabel) 买断本地转经轮") {
                                Task { await model.globalDharmaCommerce.purchaseLifetime() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!model.globalDharmaCommerce.canBuyLifetime)
                            .accessibilityIdentifier("global-dharma-buy-lifetime")
                        }

                        Button("恢复购买") {
                            Task { await model.globalDharmaCommerce.restoreLifetime() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.globalDharmaCommerce.busy)
                        .accessibilityIdentifier("global-dharma-restore-purchase")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }

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
            if plugin.pluginId == GlobalDharmaCommerceModel.miniAppId {
                await model.globalDharmaCommerce.refresh()
            }
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
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
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
                    let result = try await model.callRuntimeTool(
                        pluginId: plugin.pluginId,
                        name: name,
                        arguments: input
                    )
                    resolve(webView: webView, requestId: requestId, payload: ["ok": true, "result": result])
                } catch {
                    resolve(webView: webView, requestId: requestId, payload: [
                        "ok": false,
                        "error": error.localizedDescription,
                    ])
                }
            }
        }

        private func requestApproval(_ tool: MiniAppToolContract) async -> Bool {
            guard let presenter = topViewController() else { return false }
            let warning = tool.approval == "destructive"
                ? "该操作可能产生破坏性修改。"
                : "该操作会修改小程序或后台状态。"
            return await withCheckedContinuation { continuation in
                let alert = UIAlertController(
                    title: "允许 WebMCP 调用 \(tool.name)？",
                    message: "\(tool.description)\n\n\(warning)",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                    continuation.resume(returning: false)
                })
                alert.addAction(UIAlertAction(title: "允许", style: .default) { _ in
                    continuation.resume(returning: true)
                })
                presenter.present(alert, animated: true)
            }
        }

        private func topViewController() -> UIViewController? {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            var controller = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
            while let presented = controller?.presentedViewController {
                controller = presented
            }
            return controller
        }

        private func resolve(webView: WKWebView, requestId: String, payload: [String: Any]) {
            guard JSONSerialization.isValidJSONObject(payload),
                  let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8),
                  let requestData = try? JSONEncoder().encode(requestId),
                  let requestJson = String(data: requestData, encoding: .utf8)
            else { return }
            webView.evaluateJavaScript("window.__fabushiNativeResolve?.(\(requestJson),\(json));")
        }
    }
}

private func injectLocalWebMcp(_ html: String, plugin: MarketplacePlugin) -> String {
    let definitions = plugin.tools.map { tool in
        [
            "name": tool.name,
            "description": tool.description,
            "readOnlyHint": tool.approval == "none",
        ] as [String: Any]
    }
    let data = (try? JSONSerialization.data(withJSONObject: definitions)) ?? Data("[]".utf8)
    let toolsJson = String(data: data, encoding: .utf8) ?? "[]"
    let bootstrap = """
    <script>
    (function(){
      const definitions=\(toolsJson);
      const localTools=new Map();const controllers=[];const pending=new Map();let sequence=0;
      window.__fabushiNativeResolve=(requestId,payload)=>{const task=pending.get(requestId);if(!task)return;pending.delete(requestId);if(payload&&payload.ok)task.resolve(payload.result);else task.reject(new Error(payload?.error||'WebMCP runtime call failed'));};
      function callNative(name,input){return new Promise((resolve,reject)=>{const requestId='webmcp-'+Date.now()+'-'+(++sequence);pending.set(requestId,{resolve,reject});window.webkit.messageHandlers.\(webMcpMessageHandler).postMessage({requestId,name,input:input||{}});});}
      function publicTool(tool){const copy={...tool};delete copy.execute;return copy;}
      function register(item){const tool={name:item.name,description:item.description||item.name,inputSchema:{type:'object',properties:{}},annotations:{readOnlyHint:item.readOnlyHint===true},execute:(input)=>callNative(item.name,input)};localTools.set(tool.name,tool);if(document.modelContext&&typeof document.modelContext.registerTool==='function'){const controller=new AbortController();controllers.push(controller);Promise.resolve(document.modelContext.registerTool(tool,{signal:controller.signal})).catch(()=>{});}}
      for(const item of definitions)register(item);
      Object.defineProperty(window,'__fabushiWebMcp',{configurable:true,value:{version:1,list:()=>Array.from(localTools.values()).map(publicTool),call:async(name,input={})=>{const tool=localTools.get(name);if(!tool)throw new Error('Unknown WebMCP tool: '+name);return tool.execute(input);}}});
      window.addEventListener('pagehide',()=>{for(const controller of controllers)controller.abort();pending.clear();},{once:true});
      window.dispatchEvent(new CustomEvent('fabushi:webmcp-ready',{detail:{pluginId:\(jsonString(plugin.pluginId)),tools:definitions.map(t=>t.name)}}));
    })();
    </script>
    """
    if let range = html.range(of: "</head>", options: .caseInsensitive) {
        var result = html
        result.insert(contentsOf: bootstrap, at: range.lowerBound)
        return result
    }
    return bootstrap + html
}

private func jsonString(_ value: String) -> String {
    guard let data = try? JSONEncoder().encode(value) else { return "\"\"" }
    return String(data: data, encoding: .utf8) ?? "\"\""
}
