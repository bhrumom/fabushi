import { useEffect, useMemo, useState } from "react";
import { Button, Text, View } from "@tarojs/components";
import Taro from "@tarojs/taro";
import { leaderboardPreview, practicePlan, practiceSessionPresets } from "@fabushi/shared";
import "./index.scss";

export default function PracticePage() {
  const [activeIndex, setActiveIndex] = useState(0);
  const [seconds, setSeconds] = useState(0);
  const [chantCount, setChantCount] = useState(0);
  const [running, setRunning] = useState(false);

  const activePractice = practiceSessionPresets[activeIndex];
  const formattedTime = useMemo(() => {
    const minutes = Math.floor(seconds / 60)
      .toString()
      .padStart(2, "0");
    const rest = (seconds % 60).toString().padStart(2, "0");
    return `${minutes}:${rest}`;
  }, [seconds]);

  useEffect(() => {
    if (!running) return undefined;
    const timer = setInterval(() => setSeconds((value) => value + 1), 1000);
    return () => clearInterval(timer);
  }, [running]);

  function toggleSession() {
    setRunning((value) => !value);
  }

  function finishSession() {
    const minutes = Math.max(1, Math.round(seconds / 60));
    Taro.setStorageSync("fabushi_mp_last_practice", {
      title: activePractice.title,
      minutes,
      chantCount,
      finishedAt: new Date().toISOString(),
    });
    setRunning(false);
    setSeconds(0);
    setChantCount(0);
    Taro.showToast({ title: "功课已记录", icon: "success" });
  }

  return (
    <View className="page">
      <Text className="title">禅室修行</Text>
      <Text className="subtitle">
        复刻 Flutter 禅室的零摩擦节奏：选择功课、开始计时、念诵计数、回向并保存本地记录。
      </Text>

      <View className="timer-panel">
        <Text className="timer-label">当前功课</Text>
        <Text className="timer-title">{activePractice.title}</Text>
        <Text className="timer-value">{formattedTime}</Text>
        <Text className="timer-copy">{activePractice.dedication}</Text>
        <View className="timer-actions">
          <Button className="primary" onClick={toggleSession}>
            {running ? "暂停" : "开始修行"}
          </Button>
          <Button className="secondary" onClick={() => setChantCount((value) => value + 1)}>
            念诵 +1
          </Button>
        </View>
        <View className="session-row">
          <Text>目标 {activePractice.targetMinutes} 分钟</Text>
          <Text>念诵 {chantCount} 遍</Text>
        </View>
        <Button className="finish" disabled={seconds === 0 && chantCount === 0} onClick={finishSession}>
          功德圆满
        </Button>
      </View>

      <View className="section">
        <Text className="section-title">选择功课</Text>
        <View className="preset-grid">
          {practiceSessionPresets.map((item, index) => (
            <View
              className={`preset ${index === activeIndex ? "preset-active" : ""}`}
              key={item.title}
              onClick={() => setActiveIndex(index)}
            >
              <Text className="preset-title">{item.title}</Text>
              <Text className="preset-copy">{item.targetMinutes} 分钟</Text>
            </View>
          ))}
        </View>
      </View>

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
