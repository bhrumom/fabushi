import { View, Text } from "@tarojs/components";
import {
  aiQuickPrompts,
  appExperienceStats,
  appModules,
  brand,
  dharmaFeedItems,
} from "@fabushi/shared";
import "./index.scss";

export default function IndexPage() {
  return (
    <View className="page">
      <View className="hero">
        <Text className="eyebrow">Fabushi Mini Program</Text>
        <Text className="title">大乘微信小程序</Text>
        <Text className="subtitle">
          {brand.tagline} 微信内先承接轻浏览、经文续读、修行计划和 AI 找资源。
        </Text>
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

      <View className="section">
        <Text className="section-title">核心入口</Text>
        {appModules.map((item) => (
          <View key={item.id} className={`module module-${item.tone}`}>
            <Text className="module-icon">{item.shortTitle}</Text>
            <View className="module-body">
              <Text className="card-title">{item.title}</Text>
              <Text className="card-copy">{item.summary}</Text>
            </View>
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
