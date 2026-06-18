import { useMemo, useState } from "react";
import { Button, Input, Text, View } from "@tarojs/components";
import Taro from "@tarojs/taro";
import { aiQuickPrompts, sutraLibrary } from "@fabushi/shared";
import "./index.scss";

export default function SutraPage() {
  const [query, setQuery] = useState("");
  const [activeTitle, setActiveTitle] = useState<string>(sutraLibrary[0].title);

  const filtered = useMemo(() => {
    const keyword = query.trim();
    if (!keyword) return sutraLibrary;
    return sutraLibrary.filter((item) =>
      `${item.title}${item.category}${item.summary}`.includes(keyword),
    );
  }, [query]);

  const active = sutraLibrary.find((item) => item.title === activeTitle) ?? sutraLibrary[0];

  function openAiWithSutra() {
    Taro.setStorageSync(
      "fabushi_mp_ai_prompt",
      `${aiQuickPrompts[3]}：请围绕《${active.title}》说明。`,
    );
    Taro.switchTab({ url: "/pages/ai/index" });
  }

  return (
    <View className="page">
      <View className="header">
        <Text className="eyebrow">Sutra Reader</Text>
        <Text className="title">经文续读</Text>
        <Text className="subtitle">
          复刻 Flutter 阅读器的信息层：书架、进度、功德利益、AI 问经入口都用微信原生组件呈现。
        </Text>
      </View>

      <View className="search-panel">
        <Input
          className="search-input"
          value={query}
          placeholder="搜索经文、分类或摘要"
          onInput={(event) => setQuery(event.detail.value)}
        />
      </View>

      <View className="active-reader">
        <Text className="reader-label">当前续读</Text>
        <Text className="reader-title">《{active.title}》</Text>
        <Text className="reader-copy">{active.summary}</Text>
        <View className="reader-progress">
          <View className="reader-progress-bar" style={{ width: `${active.progress}%` }} />
        </View>
        <View className="reader-actions">
          <Button className="primary" onClick={() => Taro.showToast({ title: "已打开续读", icon: "success" })}>
            继续读诵
          </Button>
          <Button className="secondary" onClick={openAiWithSutra}>
            AI 问经
          </Button>
        </View>
      </View>

      <View className="section">
        <Text className="section-title">经文书架</Text>
      </View>

      {filtered.map((item) => (
        <View
          className={`sutra-card ${item.title === active.title ? "sutra-card-active" : ""}`}
          key={item.title}
          onClick={() => setActiveTitle(item.title)}
        >
          <View className="sutra-row">
            <View>
              <Text className="sutra-title">{item.title}</Text>
              <Text className="sutra-meta">{item.category}</Text>
            </View>
            <Text className="duration">{item.minutes} 分钟</Text>
          </View>
          <Text className="sutra-summary">{item.summary}</Text>
          <View className="progress">
            <View className="progress-bar" style={{ width: `${item.progress}%` }} />
          </View>
        </View>
      ))}

      {filtered.length === 0 && (
        <View className="empty">
          <Text>没有找到相关经文。</Text>
        </View>
      )}
    </View>
  );
}
