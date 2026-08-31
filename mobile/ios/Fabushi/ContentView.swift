import SwiftUI

private enum MobileDestination {
    case home
    case marketplace
    case remoteComputer
}

private struct ConversationSummary: Identifiable {
    let id: String
    let title: String
    let preview: String
    let time: String
    let badge: String
}

struct ContentView: View {
    @Bindable var model: MarketplaceModel
    let appAgentSurface: FabushiAppAgentSurface
    @State private var openedMiniApp: MarketplacePlugin?
    @State private var destination: MobileDestination = .home
    @State private var isSearching = false
    @State private var homeQuery = ""
    @State private var selectedConversation: ConversationSummary?
    @State private var conversations: [ConversationSummary] = []

    var body: some View {
        Group {
            switch destination {
            case .home:
                homeView
            case .marketplace:
                marketplaceView
            case .remoteComputer:
                RemoteComputerSurface { destination = .home }
            }
        }
        .fullScreenCover(item: $openedMiniApp) { plugin in
            MiniAppWebMcpSurface(plugin: plugin, model: model)
        }
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
        .task(id: appAgentSurfaceFingerprint) {
            publishAppAgentSurface()
        }
        .onDisappear {
            appAgentSurface.clear()
        }
    }

    private var appAgentSurfaceFingerprint: String {
        let pluginRevision = model.plugins.map { "\($0.pluginId):\($0.latestVersion ?? "")" }.joined(separator: ",")
        let destinationRevision: String = switch destination {
        case .home: "home"
        case .marketplace: "marketplace"
        case .remoteComputer: "remote-computer"
        }
        return [
            destinationRevision,
            String(isSearching),
            homeQuery,
            model.query,
            model.message,
            String(model.loading),
            model.installingPluginId ?? "",
            model.permissionRequest?.pluginId ?? "",
            openedMiniApp?.pluginId ?? "",
            pluginRevision,
        ].joined(separator: "|")
    }

    @MainActor
    private func publishAppAgentSurface() {
        var elements: [FabushiAppAgentSurface.Element] = []
        var actions: [String: FabushiAppAgentSurface.Action] = [:]
        func semanticId(_ value: String) -> String {
            String(value.map { character in
                character.isASCII && (character.isLetter || character.isNumber || "._:/@-".contains(character))
                    ? character
                    : "-"
            }.prefix(200))
        }
        func add(
            _ id: String,
            role: String,
            name: String,
            enabled: Bool = true,
            visible: Bool = true,
            action: FabushiAppAgentSurface.Action? = nil
        ) {
            let normalizedId = semanticId(id)
            elements.append(.init(
                agentId: normalizedId,
                role: String(role.prefix(80)),
                name: String(name.prefix(240)),
                visible: visible,
                enabled: enabled
            ))
            if let action { actions[normalizedId] = action }
        }

        let screen: String
        if let openedMiniApp {
            screen = "miniapp"
            add("miniapp-\(openedMiniApp.pluginId)", role: "application", name: openedMiniApp.displayName)
            add(
                "miniapp-close",
                role: "button",
                name: "关闭 MiniApp",
                action: .init(allowed: ["invoke"]) { _ in self.openedMiniApp = nil }
            )
        } else {
            switch destination {
            case .home:
                screen = "home"
                add("app-shell", role: "application", name: "Fabushi")
                add(
                    "home-search-button",
                    role: "button",
                    name: "搜索对话",
                    action: .init(allowed: ["invoke"]) { _ in isSearching.toggle() }
                )
                if isSearching {
                    add(
                        "home-search-field",
                        role: "textbox",
                        name: "搜索消息",
                        action: .init(allowed: ["setValue"]) { value in homeQuery = value ?? "" }
                    )
                }
                add("home-add-button", role: "button", name: "新建对话", action: .init(allowed: ["invoke"]) { _ in addConversation() })
                add(
                    "marketplace-entry",
                    role: "menuitem",
                    name: "插件市场",
                    action: .init(allowed: ["invoke"]) { _ in destination = .marketplace }
                )
                add(
                    "remote-computer-entry",
                    role: "menuitem",
                    name: "我的电脑",
                    action: .init(allowed: ["invoke"]) { _ in destination = .remoteComputer }
                )
            case .marketplace:
                screen = "marketplace"
                add(
                    "marketplace-back",
                    role: "button",
                    name: "消息",
                    action: .init(allowed: ["invoke"]) { _ in destination = .home }
                )
                add(
                    "marketplace-search",
                    role: "textbox",
                    name: "搜索插件",
                    action: .init(allowed: ["setValue"]) { value in model.query = value ?? "" }
                )
                add(
                    "marketplace-search-submit",
                    role: "button",
                    name: "搜索",
                    enabled: !model.loading,
                    action: .init(allowed: ["invoke"]) { _ in Task { await model.refresh() } }
                )
                add("host-status", role: "status", name: model.message)
                for plugin in model.plugins.prefix(100) {
                    add("plugin-\(plugin.pluginId)", role: "group", name: plugin.displayName)
                    add(
                        "open-\(plugin.pluginId)",
                        role: "button",
                        name: "打开 \(plugin.displayName)",
                        action: .init(allowed: ["invoke"]) { _ in openedMiniApp = plugin }
                    )
                    add(
                        "install-\(plugin.pluginId)",
                        role: "button",
                        name: "安装 \(plugin.displayName)",
                        enabled: plugin.latestVersion != nil && model.installingPluginId == nil,
                        action: .init(allowed: ["invoke"]) { _ in Task { await model.install(plugin) } }
                    )
                }
            case .remoteComputer:
                screen = "remote-computer"
                add("remote-computer-surface", role: "application", name: "远程控制我的电脑")
                add(
                    "remote-computer-close",
                    role: "button",
                    name: "关闭远程控制",
                    action: .init(allowed: ["invoke"]) { _ in destination = .home }
                )
            }
        }
        if model.permissionRequest != nil {
            add(
                "permission-approve",
                role: "button",
                name: "授权插件权限",
                action: .init(allowed: ["invoke"]) { _ in Task { await model.approvePermissions() } }
            )
            add(
                "permission-deny",
                role: "button",
                name: "拒绝插件权限",
                action: .init(allowed: ["invoke"]) { _ in model.denyPermissions() }
            )
        }
        try? appAgentSurface.publish(
            screen: model.permissionRequest == nil ? screen : "permission-dialog",
            elements: elements,
            actions: actions
        )
    }

    private var homeView: some View {
        ZStack {
            Color(red: 0.043, green: 0.043, blue: 0.047).ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Menu {
                            Button("我的电脑") { destination = .remoteComputer }
                                .accessibilityIdentifier("remote-computer-entry")
                            Button("插件市场") { destination = .marketplace }
                                .accessibilityIdentifier("marketplace-entry")
                        } label: { avatar }
                        Spacer()
                        circleButton(systemName: "magnifyingglass", identifier: "home-search-button") {
                            withAnimation(.easeInOut(duration: 0.18)) { isSearching.toggle() }
                        }
                        circleButton(systemName: "square.and.pencil", identifier: "home-add-button") {
                            addConversation()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 18)

                    if isSearching {
                        TextField("搜索消息", text: $homeQuery)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(Color(red: 0.082, green: 0.082, blue: 0.086), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                            .accessibilityIdentifier("home-search-field")
                    }

                    VStack(spacing: 0) {
                        ForEach(filteredConversations) { conversation in
                            conversationRow(conversation)
                        }
                        if filteredConversations.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 34, weight: .regular))
                                Text(homeQuery.isEmpty ? "还没有对话" : "没有找到匹配的消息")
                                    .font(.headline)
                                Text(homeQuery.isEmpty ? "点右上角写消息按钮开始新的对话" : "换个关键词试试")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(Color.white.opacity(0.48))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 70)
                        }
                    }
                    .accessibilityIdentifier("conversation-list")

                    if let featureHostSmokeStatus = model.featureHostSmokeStatus {
                        Text(featureHostSmokeStatus)
                            .font(.caption2)
                            .foregroundStyle(.clear)
                            .accessibilityIdentifier("feature-host-smoke")
                    }
                }
            }
        }
        .accessibilityIdentifier("app-shell")
        .fullScreenCover(item: $selectedConversation) { conversation in
            NavigationStack {
                VStack(spacing: 0) {
                    Spacer()
                    Text("开始与 \(conversation.title) 对话")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 10) {
                        TextField("消息", text: .constant(""))
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                    }
                    .padding()
                }
                .navigationTitle(conversation.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("返回") { selectedConversation = nil }
                    }
                }
            }
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.082, green: 0.082, blue: 0.086))
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            Text("✦")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.10))
        }
        .frame(width: 56, height: 56)
        .accessibilityLabel("个人头像")
        .accessibilityIdentifier("profile-avatar")
    }

    private func circleButton(systemName: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.063, green: 0.063, blue: 0.067))
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                Image(systemName: systemName)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)
        }
        .accessibilityIdentifier(identifier)
    }

    private func conversationRow(_ conversation: ConversationSummary) -> some View {
        HStack(spacing: 0) {
            ZStack {
                Circle().fill(Color(red: 1.0, green: 0.35, blue: 0.04))
                Text(conversation.badge)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color(red: 0.10, green: 0.06, blue: 0.03))
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 5) {
                Text(conversation.title)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(1)
                Text(conversation.preview)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .lineLimit(1)
            }
            .padding(.leading, 18)

            Spacer(minLength: 12)

            Text(conversation.time)
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.30))
        }
        .padding(.leading, 30)
        .padding(.trailing, 24)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .onTapGesture { selectedConversation = conversation }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("conversation-\(conversation.id)")
    }

    private var filteredConversations: [ConversationSummary] {
        guard !homeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return conversations }
        return conversations.filter {
            $0.title.localizedCaseInsensitiveContains(homeQuery) || $0.preview.localizedCaseInsensitiveContains(homeQuery)
        }
    }

    private func addConversation() {
        let next = conversations.count + 1
        let conversation = ConversationSummary(id: "new-\(next)", title: "新对话 \(next)", preview: "开始一段新的对话", time: "现在", badge: "✦")
        conversations.insert(conversation, at: 0)
        selectedConversation = conversation
    }

    private var marketplaceView: some View {
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
                        .accessibilityElement(children: .contain)
                    }
                    .accessibilityElement(children: .contain)
                }

                Section("本地插件市场") {
                    Text("iOS 主壳使用 SwiftUI；MiniApp 使用受控 WebMCP Surface；插件安装、权限与后台运行由共享 Mahayana Rust Host 管理。")
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
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("host-status")

                    if let featureHostSmokeStatus = model.featureHostSmokeStatus {
                        Text(featureHostSmokeStatus)
                            .accessibilityIdentifier("feature-host-smoke")
                    }
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

                            HStack(spacing: 8) {
                                Button("打开 WebMCP") {
                                    openedMiniApp = plugin
                                }
                                .accessibilityIdentifier("open-\(plugin.pluginId)")

                                Button(model.installingPluginId == plugin.pluginId ? "处理中…" : "安装 / 更新") {
                                    Task { await model.install(plugin) }
                                }
                                .disabled(plugin.latestVersion == nil || model.installingPluginId != nil)
                                .accessibilityIdentifier("install-\(plugin.pluginId)")
                            }
                        }
                    }
                }
            }
            .navigationTitle("法布施")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("消息") { destination = .home }
                }
            }
            .refreshable { await model.refresh() }
            .task {
                if model.plugins.isEmpty {
                    await model.refresh()
                }
            }
        }
    }
}
