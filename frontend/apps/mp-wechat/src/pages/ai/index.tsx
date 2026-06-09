import { useState } from "react";
import { Button, Input, Text, Textarea, View } from "@tarojs/components";
import Taro from "@tarojs/taro";
import { aiQuickPrompts } from "@fabushi/shared";
import "./index.scss";

const AI_BASE =
  process.env.TARO_APP_DACHENG_AI_API_BASE_URL?.replace(/\/+$/, "") ||
  "https://fabushi.ombhrum.com/api/dacheng-ai";

interface ChatPayload {
  success?: boolean;
  message?: string;
}

interface ResourceItem {
  id: string;
  title: string;
  sourceName: string;
  snippet: string;
  resourceType: string;
  url: string;
}

export default function AiPage() {
  const [prompt, setPrompt] = useState<string>(aiQuickPrompts[0]);
  const [answer, setAnswer] = useState("等待提问。");
  const [status, setStatus] = useState("已连接大乘 AI 网关");
  const [loading, setLoading] = useState(false);
  const [query, setQuery] = useState("心经 可公开分享 经文");
  const [resources, setResources] = useState<ResourceItem[]>([]);

  async function sendPrompt() {
    const text = prompt.trim();
    if (!text || loading) return;
    setLoading(true);
    setStatus("生成中");
    try {
      const response = await Taro.request<ChatPayload>({
        url: `${AI_BASE}/api/ai/chat`,
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
      setAnswer(response.data.message || "AI 暂未返回内容。");
      setStatus("已生成");
    } catch (error) {
      setAnswer(error instanceof Error ? error.message : "大乘 AI 暂不可用");
      setStatus("生成失败");
    } finally {
      setLoading(false);
    }
  }

  async function searchResources() {
    const text = query.trim();
    if (!text) return;
    setStatus("搜索资源中");
    try {
      const response = await Taro.request<{ success?: boolean; items?: ResourceItem[]; message?: string }>({
        url: `${AI_BASE}/api/resources/search`,
        method: "POST",
        header: {
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        data: { query: text, limit: 6 },
        timeout: 30000,
      });
      if (response.statusCode < 200 || response.statusCode >= 300 || response.data.success === false) {
        throw new Error(response.data.message || `请求失败 ${response.statusCode}`);
      }
      setResources(response.data.items || []);
      setStatus(`找到 ${(response.data.items || []).length} 个资源`);
    } catch (error) {
      setResources([]);
      setStatus(error instanceof Error ? error.message : "搜索失败");
    }
  }

  return (
    <View className="page">
      <Text className="title">大乘 AI</Text>
      <Text className="subtitle">小程序版使用非流式回答，适合微信内快速问经、找资源和整理发愿文。</Text>

      <View className="panel">
        <Text className="panel-title">快捷任务</Text>
        {aiQuickPrompts.map((item) => (
          <View className="prompt" key={item} onClick={() => setPrompt(item)}>
            <Text>{item}</Text>
          </View>
        ))}
      </View>

      <View className="panel">
        <Text className="panel-title">对话</Text>
        <Textarea
          className="textarea"
          value={prompt}
          maxlength={1600}
          onInput={(event) => setPrompt(event.detail.value)}
        />
        <View className="actions">
          <Button className="button" loading={loading} onClick={sendPrompt}>
            发送
          </Button>
        </View>
        <Text className="status">{status}</Text>
        <Text className="message">{answer}</Text>
      </View>

      <View className="panel">
        <Text className="panel-title">AI 找资源</Text>
        <Input className="input" value={query} onInput={(event) => setQuery(event.detail.value)} />
        <View className="actions">
          <Button className="button secondary" onClick={searchResources}>
            搜索
          </Button>
        </View>
        {resources.map((item) => (
          <View className="resource" key={item.id}>
            <Text className="resource-title">{item.title}</Text>
            <Text className="resource-copy">
              {item.sourceName} · {item.resourceType}
            </Text>
            <Text className="resource-copy">{item.snippet}</Text>
          </View>
        ))}
      </View>
    </View>
  );
}
