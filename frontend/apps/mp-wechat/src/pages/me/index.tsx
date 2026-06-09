import { View, Text } from "@tarojs/components";
import { brand } from "@fabushi/shared";
import "./index.scss";

const entries = [
  ["Web 版", "https://fabushi.ombhrum.com/app"],
  ["大乘 AI", "https://fabushi.ombhrum.com/app/ai"],
  ["支持邮箱", "support@ombhrum.com"],
] as const;

export default function MePage() {
  return (
    <View className="page">
      <View className="profile">
        <Text className="avatar">法</Text>
        <View>
          <Text className="name">{brand.englishName}</Text>
          <Text className="copy">{brand.mission}</Text>
        </View>
      </View>

      <View className="section">
        <Text className="section-title">服务入口</Text>
        {entries.map(([title, value]) => (
          <View className="item" key={title}>
            <Text className="item-title">{title}</Text>
            <Text className="copy">{value}</Text>
          </View>
        ))}
      </View>

      <View className="section">
        <Text className="section-title">版本</Text>
        <View className="item">
          <Text className="item-title">微信小程序首版</Text>
          <Text className="copy">经文、修行、AI、榜单和 Web 入口已经打通，后续继续补登录与深度共修能力。</Text>
        </View>
      </View>
    </View>
  );
}
