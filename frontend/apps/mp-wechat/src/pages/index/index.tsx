import { View, Text } from "@tarojs/components";
import { brand, homeHighlights } from "@fabushi/shared";
import "./index.scss";

export default function IndexPage() {
  return (
    <View className="page">
      <View className="hero">
        <Text className="eyebrow">Fabushi Mini Program</Text>
        <Text className="title">{brand.tagline}</Text>
        <Text className="subtitle">
          小程序首期先承接轻浏览、榜单、公开档案与微信生态内的便捷触达。
        </Text>
      </View>

      <View className="section">
        <Text className="section-title">首期重点</Text>
        {homeHighlights.map((item) => (
          <View key={item.title} className="card">
            <Text className="card-title">{item.title}</Text>
            <Text className="card-copy">{item.description}</Text>
          </View>
        ))}
      </View>

      <View className="section">
        <Text className="section-title">后端复用</Text>
        <View className="card">
          <Text className="card-copy">
            继续共用现有 Cloudflare Workers API 与数据层，把多端差异压缩在前端展现层。
          </Text>
        </View>
      </View>
    </View>
  );
}
