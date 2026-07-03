import { useState, useEffect } from "react";
import { Button, Input, Text, View, Image } from "@tarojs/components";
import Taro from "@tarojs/taro";
import { aiQuickPrompts } from "@fabushi/shared";
import {
  dachengAiEndpoints,
  getDachengAiApiBaseUrl,
  API_BASE_URL,
  type DachengAiChatResponse,
} from "@fabushi/api-client";
import "./index.scss";

const AI_BASE = getDachengAiApiBaseUrl();

type ChatMessage = {
  id: string;
  role: "assistant" | "user";
  text: string;
};

const suggestions = [
  { icon: "✦", label: "大乘能做什么", prompt: aiQuickPrompts[0] },
  { icon: "◉", label: "开始全球法布施", prompt: "", route: "/pages/globe/index" },
  { icon: "⌁", label: "安装 Hermes", prompt: "", route: "/pages/hermes/index" },
  { icon: "⌕", label: "AI找资源", prompt: "请帮我找适合初学者阅读的佛经资源。" },
  { icon: "▣", label: "加入功课本", prompt: "帮我整理一份今天可以完成的简短功课。" },
  { icon: "♡", label: "发愿文案", prompt: "请帮我润色一段慈悲、简洁的发愿文案。" },
];

export default function IndexPage() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [draft, setDraft] = useState("");
  const [loading, setLoading] = useState(false);
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    const savedUser = Taro.getStorageSync("fabushi_user");
    if (savedUser) {
      try {
        setUser(JSON.parse(savedUser));
      } catch (e) {}
    }
  }, []);

  const [messages, setMessages] = useState<ChatMessage[]>([
    {
      id: "welcome",
      role: "assistant",
      text: "你好，我是大乘。你可以问经文、找资源，或让我帮你整理可分享的善法内容。",
    },
  ]);

  function handleSuggestionClick(item: typeof suggestions[0]) {
    if (item.route) {
      Taro.navigateTo({ url: item.route });
    } else {
      setDraft(item.prompt);
    }
  }

  function startNewChat() {
    setMessages([]);
    setDraft("");
    setSidebarOpen(false);
  }

  async function handleWechatLogin() {
    try {
      Taro.showLoading({ title: "登录中..." });
      const { code } = await Taro.login();
      if (!code) throw new Error("获取微信 code 失败");

      const response = await Taro.request({
        url: `${API_BASE_URL}/api/auth/wechat/mp-login`,
        method: "POST",
        data: { code }
      });

      if (response.statusCode === 200 && response.data.success) {
        const { user, token } = response.data;
        setUser(user);
        Taro.setStorageSync("fabushi_user", JSON.stringify(user));
        Taro.setStorageSync("fabushi_token", token);
        Taro.showToast({ title: "登录成功", icon: "success" });
      } else {
        throw new Error(response.data.error || "登录失败");
      }
    } catch (e: any) {
      Taro.showToast({ title: e.message || "登录出错", icon: "none" });
    } finally {
      Taro.hideLoading();
    }
  }

  async function sendMessage() {
    const text = draft.trim();
    if (!text || loading) return;

    const userMessage: ChatMessage = {
      id: `user-${Date.now()}`,
      role: "user",
      text,
    };
    setMessages((current) => [...current, userMessage]);
    setDraft("");
    setLoading(true);

    try {
      const response = await Taro.request<DachengAiChatResponse>({
        url: `${AI_BASE}${dachengAiEndpoints.chat}`,
        method: "POST",
        header: {
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        data: {
          message: text,
          clientMembershipHint: false,
        },
        timeout: 60000,
      });

      if (response.statusCode < 200 || response.statusCode >= 300 || response.data.success === false) {
        throw new Error(response.data.message || `请求失败 ${response.statusCode}`);
      }

      setMessages((current) => [
        ...current,
        {
          id: `assistant-${Date.now()}`,
          role: "assistant",
          text: response.data.message || "AI 暂未返回内容。",
        },
      ]);
    } catch (error) {
      setMessages((current) => [
        ...current,
        {
          id: `error-${Date.now()}`,
          role: "assistant",
          text: error instanceof Error ? error.message : "大乘 AI 暂不可用，请稍后再试。",
        },
      ]);
    } finally {
      setLoading(false);
    }
  }

  return (
    <View className="chat-page">
      <View className="topbar">
        <Button className="menu-button" onClick={() => setSidebarOpen(true)}>
          ☰
        </Button>
        <Text className="brand">大乘</Text>
      </View>

      <View className="chat-main">
        <View className="intro">
          <Text className="greeting">Hi, {user ? (user.nickname || user.username) : '朋友'}</Text>
          <Text className="subtitle">把可分享的善法资源，带到全球</Text>
        </View>

        <View className="suggestions">
          {suggestions.map((item) => (
            <Button className="suggestion" key={item.label} onClick={() => handleSuggestionClick(item)}>
              <Text className="suggestion-icon">{item.icon}</Text>
              <Text>{item.label}</Text>
            </Button>
          ))}
        </View>

        <View className="messages">
          {messages.map((message) => (
            <View className={`message ${message.role}`} key={message.id}>
              <Text>{message.text}</Text>
            </View>
          ))}
          {loading && (
            <View className="message assistant">
              <Text>正在生成...</Text>
            </View>
          )}
        </View>
      </View>

      <View className="composer">
        <Button className="add-button">＋</Button>
        <Input
          className="chat-input"
          value={draft}
          placeholder="问问大乘"
          confirmType="send"
          onInput={(event) => setDraft(event.detail.value)}
          onConfirm={sendMessage}
        />
        <Button className="send-button" loading={loading} onClick={sendMessage}>
          ↑
        </Button>
      </View>

      {sidebarOpen && <View className="scrim" onClick={() => setSidebarOpen(false)} />}
      <View className={`sidebar ${sidebarOpen ? "open" : ""}`}>
        <View className="sidebar-header">
          <Text className="sidebar-title">大乘</Text>
          <Button className="close-button" onClick={() => setSidebarOpen(false)}>
            ×
          </Button>
        </View>

        <View className="sidebar-user">
          {user ? (
            <View className="user-profile">
              <Image className="user-avatar" src={user.avatar || "https://mmbiz.qpic.cn/mmbiz/icTdbqWNOwNRna42FI242Lcia07jQodd2FJGIYQfG0LAJGFxM4FbnQP6yfMxBgJ0F3YRqJCJ1aPAK2dQagdusBZg/0"} />
              <View className="user-info">
                <Text className="user-name">{user.nickname || user.username}</Text>
                <Text className="user-membership">{user.membership?.type === 'expired' ? '普通用户' : '会员用户'}</Text>
              </View>
            </View>
          ) : (
            <Button className="wechat-login-btn" onClick={handleWechatLogin}>
              <Text className="wechat-icon">⚏</Text>
              <Text>微信快捷登录</Text>
            </Button>
          )}
        </View>

        <Button className="new-chat" onClick={startNewChat}>
          <Text className="new-chat-icon">⊞</Text>
          <Text>开启新对话</Text>
        </Button>
        <Text className="today">今天</Text>
        <View className="empty">
          <Text>没有更多内容啦</Text>
        </View>
      </View>
    </View>
  );
}
