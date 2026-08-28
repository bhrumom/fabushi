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
    @State private var openedMiniApp: MarketplacePlugin?
    @State private var destination: MobileDestination = .home
    @State private var isSearching = false
    @State private var homeQuery = ""
    @State private var conversations: [ConversationSummary] = [
        ConversationSummary(
            id: "chief-of-staff",
            title: "Chief of Staff",
            preview: "I can also pull in email, Slack, or other tools…",
            time: "02:41",
            badge: "••"
        )
    ]

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
    }

    private var homeView: some View {
        ZStack {
            Color(red: 0.043, green: 0.043, blue: 0.047).ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 0) {
                    HStack(spacing: 12) {
                        avatar
                        Spacer()
                        circleButton(systemName: "magnifyingglass", identifier: "home-search-button") {
                            withAnimation(.easeInOut(duration: 0.18)) { isSearching.toggle() }
                        }
                        Menu {
                            Button("新建对话") { addConversation() }
                            Button("我的电脑") { destination = .remoteComputer }
                                .accessibilityIdentifier("remote-computer-entry")
                            Button("插件市场") { destination = .marketplace }
                                .accessibilityIdentifier("marketplace-entry")
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.063, green: 0.063, blue: 0.067))
                                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                                Image(systemName: "plus")
                                    .font(.system(size: 23, weight: .regular))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 54, height: 54)
                        }
                        .accessibilityIdentifier("home-add-button")
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
                            Text("没有找到匹配的消息")
                                .foregroundStyle(Color.white.opacity(0.48))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 28)
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
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(conversation.id == "chief-of-staff" ? "conversation-chief-of-staff" : "conversation-\(conversation.id)")
    }

    private var filteredConversations: [ConversationSummary] {
        guard !homeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return conversations }
        return conversations.filter {
            $0.title.localizedCaseInsensitiveContains(homeQuery) || $0.preview.localizedCaseInsensitiveContains(homeQuery)
        }
    }

    private func addConversation() {
        let next = conversations.count + 1
        conversations.insert(
            ConversationSummary(id: "new-\(next)", title: "新对话 \(next)", preview: "开始一段新的对话", time: "现在", badge: "+"),
            at: 0
        )
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
