import SwiftUI

struct ContentView: View {
    @Bindable var model: MarketplaceModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MAHAYANA RUST HOST")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("全球法布施").font(.largeTitle.bold())
                            Spacer()
                            Text("SwiftUI · Rust")
                                .font(.caption.bold())
                                .accessibilityIdentifier("runtime-badge")
                        }
                    }
                    .accessibilityIdentifier("app-shell")
                }

                Section("本地插件市场") {
                    Text("iOS UI 使用 SwiftUI；插件安装、权限与运行时由共享 Mahayana Rust Host 管理。")
                    TextField("搜索插件", text: $model.query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("marketplace-search")
                    Button("搜索") {
                        Task { await model.refresh() }
                    }
                    .disabled(model.loading)
                    .accessibilityIdentifier("marketplace-search-submit")
                }

                Section("Host 状态") {
                    HStack(spacing: 12) {
                        if model.loading { ProgressView() }
                        Text(model.message)
                    }
                    .accessibilityIdentifier("host-status")
                }

                Section("插件") {
                    if model.plugins.isEmpty && !model.loading {
                        Text("没有匹配的 iOS 插件。")
                    }
                    ForEach(model.plugins) { plugin in
                        VStack(alignment: .leading, spacing: 8) {
                            Group {
                                Text(plugin.pluginId).font(.caption.monospaced()).foregroundStyle(.secondary)
                                Text(plugin.displayName).font(.headline)
                                Text(plugin.description).foregroundStyle(.secondary)
                                if let version = plugin.latestVersion { Text(version).font(.caption) }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("plugin-\(plugin.pluginId)")

                            Button(model.installingPluginId == plugin.pluginId ? "处理中…" : "安装 / 更新") {
                                Task { await model.install(plugin) }
                            }
                            .disabled(plugin.latestVersion == nil || model.installingPluginId != nil)
                            .accessibilityIdentifier("install-\(plugin.pluginId)")
                        }
                    }
                }
            }
            .navigationTitle("法布施")
            .refreshable { await model.refresh() }
            .alert("插件权限", isPresented: Binding(
                get: { model.permissionRequest != nil },
                set: { if !$0 { model.denyPermissions() } }
            )) {
                Button("拒绝", role: .cancel) { model.denyPermissions() }
                    .accessibilityIdentifier("permission-deny")
                Button("授权") { Task { await model.approvePermissions() } }
                    .accessibilityIdentifier("permission-approve")
            } message: {
                if let request = model.permissionRequest {
                    Text("\(request.pluginId) 请求以下权限：\n\(request.permissions.joined(separator: "\n"))")
                }
            }
        }
    }
}
