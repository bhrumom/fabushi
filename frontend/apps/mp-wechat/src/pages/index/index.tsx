import { useState } from "react";
import { Button, Input, Text, View } from "@tarojs/components";
import Taro from "@tarojs/taro";
import {
  aiQuickPrompts,
  appExperienceStats,
  brand,
  dharmaFeedItems,
  globalDharmaActions,
  miniProgramFlutterParity,
} from "@fabushi/shared";
import "./index.scss";

export default function IndexPage() {
  const [draft, setDraft] = useState<string>(aiQuickPrompts[0]);

  function switchTo(url: string) {
    Taro.switchTab({ url });
  }

  function copyDraft() {
    Taro.setClipboardData({
      data: draft,
      success: () => Taro.showToast({ title: "已复制", icon: "success" }),
    });
  }

  return (
    <View className="page">
      <View className="hero">
        <Text className="eyebrow">{brand.englishName}</Text>
        <Text className="title">全球法布施</Text>
        <Text className="subtitle">
          复用 Flutter App 的首页信息架构与视觉 token，用微信原生组件承接发送、问经和共修入口。
        </Text>
      </View>

      <View className="globe">
        <View className="orbit orbit-a" />
        <View className="orbit orbit-b" />
        <View className="beam beam-a" />
        <View className="beam beam-b" />
        <View className="node node-cn" />
        <View className="node node-us" />
        <View className="node node-sg" />
        <View className="node node-eu" />
        <View className="globe-core">
          <Text className="globe-value">64</Text>
          <Text className="globe-label">在线国家</Text>
        </View>
      </View>

      <View className="stats">
        {appExperienceStats.map((item) => (
          <View className="stat" key={item.label}>
            <Text className="stat-value">{item.value}</Text>
            <Text className="stat-label">
              {item.label} · {item.unit}
            </Text>
          </View>
        ))}
      </View>

      <View className="composer">
        <Text className="section-title">法布施输入</Text>
        <Input
          className="input"
          value={draft}
          maxlength={120}
          onInput={(event) => setDraft(event.detail.value)}
        />
        <View className="actions">
          <Button className="primary" onClick={() => switchTo("/pages/ai/index")}>
            AI 润色
          </Button>
          <Button className="secondary" onClick={copyDraft}>
            复制发愿
          </Button>
        </View>
      </View>

      <View className="section action-grid">
        {globalDharmaActions.map((item, index) => (
          <View className="action-card" key={item.label}>
            <Text className="action-index">0{index + 1}</Text>
            <Text className="card-title">{item.label}</Text>
            <Text className="card-copy">{item.detail}</Text>
          </View>
        ))}
      </View>

      <View className="section">
        <Text className="section-title">AI 快捷任务</Text>
        {aiQuickPrompts.slice(0, 3).map((prompt) => (
          <View className="prompt" key={prompt}>
            <Text>{prompt}</Text>
          </View>
        ))}
      </View>

      <View className="section">
        <Text className="section-title">Flutter 复用映射</Text>
        {miniProgramFlutterParity.slice(0, 3).map((item) => (
          <View className="parity" key={item.flutter}>
            <Text className="card-title">{item.title}</Text>
            <Text className="card-copy">{item.reused}</Text>
          </View>
        ))}
      </View>

      <View className="section">
        <Text className="section-title">今日法流</Text>
        {dharmaFeedItems.map((item) => (
          <View className="feed" key={item.title}>
            <Text className="card-title">{item.title}</Text>
            <Text className="card-copy">
              {item.tag} · {item.readTime}
            </Text>
          </View>
        ))}
      </View>
    </View>
  );
}
