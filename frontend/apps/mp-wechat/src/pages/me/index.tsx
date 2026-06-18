import { Button, Text, View } from "@tarojs/components";
import Taro from "@tarojs/taro";
import {
  brand,
  miniProgramFlutterParity,
  miniProgramNativeLimitations,
} from "@fabushi/shared";
import "./index.scss";

const entries = [
  ["修行记录", "本地记录已接入，云端同步等待微信登录"],
  ["账号登录", "后续接入微信 code 换取大乘账号会话"],
  ["隐私与设置", "复用 Flutter 设置页的信息架构"],
  ["支持邮箱", "support@ombhrum.com"],
] as const;

export default function MePage() {
  function handleEntry(title: string, value: string) {
    if (value.includes("@") || value.startsWith("http")) {
      Taro.setClipboardData({
        data: value,
        success: () => Taro.showToast({ title: "已复制", icon: "success" }),
      });
      return;
    }
    Taro.showToast({ title, icon: "none" });
  }

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
          <Button className="item" key={title} onClick={() => handleEntry(title, value)}>
            <Text className="item-title">{title}</Text>
            <Text className="copy">{value}</Text>
          </Button>
        ))}
      </View>

      <View className="section">
        <Text className="section-title">复用边界</Text>
        {miniProgramFlutterParity.map((item) => (
          <View className="item" key={item.flutter}>
            <Text className="item-title">{item.title}</Text>
            <Text className="copy">{item.nativeScope}</Text>
          </View>
        ))}
      </View>

      <View className="section">
        <Text className="section-title">非 WebView 说明</Text>
        <View className="item">
          {miniProgramNativeLimitations.map((item) => (
            <Text className="copy" key={item}>
              {item}
            </Text>
          ))}
        </View>
      </View>
    </View>
  );
}
