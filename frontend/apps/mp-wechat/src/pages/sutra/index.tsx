import { View, Text } from "@tarojs/components";
import { sutraLibrary } from "@fabushi/shared";
import "./index.scss";

export default function SutraPage() {
  return (
    <View className="page">
      <View className="header">
        <Text className="eyebrow">Sutra Library</Text>
        <Text className="title">经文听诵</Text>
        <Text className="subtitle">微信内先承接书架、进度和摘要，完整听诵继续复用大乘后端与原生 App 能力。</Text>
      </View>

      {sutraLibrary.map((item) => (
        <View className="sutra-card" key={item.title}>
          <View className="sutra-row">
            <View>
              <Text className="sutra-title">{item.title}</Text>
              <Text className="sutra-meta">{item.category}</Text>
            </View>
            <Text className="duration">{item.minutes} 分钟</Text>
          </View>
          <Text className="sutra-summary">{item.summary}</Text>
          <View className="progress">
            <Text className="progress-bar" style={{ width: `${item.progress}%` }} />
          </View>
        </View>
      ))}
    </View>
  );
}
