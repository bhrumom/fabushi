import { useState } from "react";
import { Button, Input, Text, View } from "@tarojs/components";
import Taro from "@tarojs/taro";
import { aiQuickPrompts } from "@fabushi/shared";
import {
  dachengAiEndpoints,
  getDachengAiApiBaseUrl,
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
  { icon: "◉", label: "开始全球法布施", prompt: "帮我写一段适合公开分享的佛法发愿文。" },
  { icon: "⌕", label: "AI找资源", prompt: "请帮我找适合初学者阅读的佛经资源。" },
  { icon: "▣", label: "加入功课本", prompt: "帮我整理一份今天可以完成的简短功课。" },
  { icon: "♡", label: "发愿文案", prompt: "请帮我润色一段慈悲、简洁的发愿文案。" },
];

export default function IndexPage() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [draft, setDraft] = useState("");
  const [loading, setLoading] = useState(false);
  const [messages, setMessages] = useState<ChatMessage[]>([
    {
      id: "welcome",
      role: "assistant",
      text: "你好，我是大乘。你可以问经文、找资源，或让我帮你整理可分享的善法内容。",
    },
  ]);

  function startPrompt(prompt: string) {
    setDraft(prompt);
  }

  function startNewChat() {
    setMessages([]);
    setDraft("");
    setSidebarOpen(false);
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
        <View className="user-pill">
          <Text>bhrum108</Text>
        </View>
      </View>

      <View className="chat-main">
        <View className="intro">
          <Text className="greeting">Hi, bhrum108</Text>
          <Text className="subtitle">把可分享的善法资源，带到全球</Text>
        </View>

        <View className="suggestions">
          {suggestions.map((item) => (
            <Button className="suggestion" key={item.label} onClick={() => startPrompt(item.prompt)}>
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
