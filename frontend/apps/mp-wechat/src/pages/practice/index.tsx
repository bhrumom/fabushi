import { View, Text } from "@tarojs/components";
import { leaderboardPreview, practicePlan } from "@fabushi/shared";
import "./index.scss";

export default function PracticePage() {
  return (
    <View className="page">
      <Text className="title">今日修行</Text>
      <Text className="subtitle">把定课、听诵、回向与共修榜单放在同一屏，适合微信内快速查看。</Text>

      <View className="section">
        <Text className="section-title">计划</Text>
        {practicePlan.map((item) => (
          <View className="card" key={item.title}>
            <Text className="card-title">{item.title}</Text>
            <Text className="card-meta">{item.duration}</Text>
            <Text className="card-copy">{item.detail}</Text>
          </View>
        ))}
      </View>

      <View className="section">
        <Text className="section-title">共修榜</Text>
        {leaderboardPreview.map((item) => (
          <View className="rank" key={item.name}>
            <Text className="rank-no">{item.rank}</Text>
            <View className="rank-body">
              <Text className="card-title">{item.name}</Text>
              <Text className="card-copy">{item.region}</Text>
            </View>
            <Text className="rank-value">{item.value}</Text>
          </View>
        ))}
      </View>
    </View>
  );
}
