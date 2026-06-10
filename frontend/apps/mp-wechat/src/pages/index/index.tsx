import { useState } from "react";
import { Button, Text, Textarea, View } from "@tarojs/components";
import Taro from "@tarojs/taro";
import {
  dachengQuickPrompts,
  dachengToolEntries,
  globalDharmaPublicEndpoints,
  globalDharmaRegions,
  remnoteInspiredFlashcardPrinciples,
  type DachengToolId,
} from "@fabushi/shared";
import "./index.scss";

type Role = "assistant" | "user";

interface Message {
  id: string;
  role: Role;
  text: string;
  tag?: string;
}

interface Card {
  id: string;
  front: string;
  back: string;
  kind: "挖空" | "双向";
  due: string;
}

function id() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function makeCards(text: string): Card[] {
  return text
    .split(/[。！？!?；;\n]+/)
    .map((item) => item.trim())
    .filter((item) => item.length > 5)
    .slice(0, 5)
    .flatMap((sentence) => [
      {
        id: id(),
        front: `${sentence.slice(0, 8)}〔……〕${sentence.slice(14)}`,
        back: sentence,
        kind: "挖空" as const,
        due: "现在",
      },
      {
        id: id(),
        front: `请背诵并解释：${sentence.slice(0, 16)}…`,
        back: sentence,
        kind: "双向" as const,
        due: "现在",
      },
    ]);
}

export default function IndexPage() {
  const [messages, setMessages] = useState<Message[]>([
    { id: "welcome", role: "assistant", text: "欢迎来到大乘。点击 + 可选择全球法布施或背诵闪卡。" },
  ]);
  const [input, setInput] = useState("");
  const [tool, setTool] = useState<DachengToolId | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [logs, setLogs] = useState<string[]>([]);
  const [cards, setCards] = useState<Card[]>([]);
  const [cardIndex, setCardIndex] = useState(0);
  const [showAnswer, setShowAnswer] = useState(false);
  const activeTool = dachengToolEntries.find((item) => item.id === tool);
  const activeCard = cards[cardIndex];

  function add(role: Role, text: string, tag?: string) {
    setMessages((items) => [...items, { id: id(), role, text, tag }]);
  }

  async function sendGlobal(text: string) {
    const nextLogs: string[] = [];
    add("assistant", "开始全球法布施。小程序版只使用 HTTP 全球公共端点，不提供法布施到平台。", "全球法布施");
    for (const [index, region] of globalDharmaRegions.entries()) {
      const endpoint = globalDharmaPublicEndpoints[index % globalDharmaPublicEndpoints.length];
      try {
        const response = await Taro.request({
          url: endpoint.url,
          method: "POST",
          header: { "Content-Type": "application/json" },
          data: { source: "dacheng-wechat", region, text, timestamp: Date.now() },
          timeout: 12000,
        });
        nextLogs.push(`${response.statusCode < 400 ? "✓" : "!"} ${region} · ${endpoint.label}`);
      } catch {
        nextLogs.push(`! ${region} · ${endpoint.label} · 待重试`);
      }
      setLogs([...nextLogs]);
    }
    add("assistant", `全球法布施完成：已处理 ${globalDharmaRegions.length} 个地区。`, "全球法布施");
  }

  function makeDeck(text: string) {
    const nextCards = makeCards(text);
    setCards((items) => [...nextCards, ...items]);
    setCardIndex(0);
    setShowAnswer(false);
    add("assistant", nextCards.length ? `已制作 ${nextCards.length} 张背诵闪卡。` : "内容太短，请补充正文后再制卡。", "背诵闪卡");
  }

  function submit() {
    const text = input.trim() || "愿以此功德，普及于一切，我等与众生，皆共成佛道。";
    setInput("");
    add("user", text, activeTool?.title);
    if (tool === "global-dharma") void sendGlobal(text);
    else if (tool === "flashcards") makeDeck(text);
    else add("assistant", "已收到。可以继续输入，或点 + 进入全球法布施和背诵闪卡。");
  }

  function review(label: string) {
    if (!activeCard) return;
    setCards((items) => items.map((card) => card.id === activeCard.id ? { ...card, due: label } : card));
    setCardIndex((index) => cards.length ? (index + 1) % cards.length : 0);
    setShowAnswer(false);
  }

  return (
    <View className="page">
      <View className="topbar">
        <Text className="brand">大乘</Text>
        <Button className="login">支付宝登录</Button>
      </View>

      <View className="messages">
        {messages.length <= 1 && (
          <View className="empty">
            <Text className="title">你在忙什么？</Text>
            <Text className="subtitle">输入问题或正文；点击 + 选择全球法布施、背诵闪卡。</Text>
            {dachengQuickPrompts.map((prompt) => (
              <View className="quick" key={prompt} onClick={() => setInput(prompt)}>
                <Text>{prompt}</Text>
              </View>
            ))}
          </View>
        )}
        {messages.map((message) => (
          <View className={`message ${message.role}`} key={message.id}>
            <Text className="avatar">{message.role === "user" ? "我" : "大"}</Text>
            <Text className="bubble">{message.tag ? `${message.tag}：` : ""}{message.text}</Text>
          </View>
        ))}
      </View>

      <View className="side-panels">
        <View className="panel">
          <Text className="panel-title">全球法布施</Text>
          <Text className="panel-copy">Web 和小程序均不显示“法布施到平台”。</Text>
          {(logs.length ? logs : ["等待发送任务"]).map((line) => <Text className="log" key={line}>{line}</Text>)}
        </View>
        <View className="panel">
          <Text className="panel-title">背诵闪卡</Text>
          <Text className="panel-copy">{cards.length ? `${cards.length} 张卡片` : "暂无卡片"}</Text>
          {activeCard && (
            <View className="flashcard">
              <Text className="card-kind">{activeCard.kind} · {activeCard.due}</Text>
              <Text className="card-front">{activeCard.front}</Text>
              {showAnswer ? <Text className="card-back">{activeCard.back}</Text> : <Button onClick={() => setShowAnswer(true)}>显示答案</Button>}
              <View className="reviews">
                {remnoteInspiredFlashcardPrinciples.slice(0, 4).map((_, index) => {
                  const labels = ["Again", "Hard", "Good", "Easy"];
                  return <Button key={labels[index]} onClick={() => review(labels[index])}>{labels[index]}</Button>;
                })}
              </View>
            </View>
          )}
        </View>
      </View>

      {menuOpen && (
        <View className="menu">
          {dachengToolEntries.map((item) => (
            <View className="menu-item" key={item.id} onClick={() => { setTool(item.id); setMenuOpen(false); }}>
              <Text className="menu-title">{item.title}</Text>
              <Text className="menu-copy">{item.description}</Text>
            </View>
          ))}
        </View>
      )}

      <View className="composer">
        <Button className="plus" onClick={() => setMenuOpen(!menuOpen)}>+</Button>
        <Textarea className="input" value={input} maxlength={1800} onInput={(event) => setInput(event.detail.value)} placeholder="有问题，尽管问" />
        {activeTool && <Button className="mode" onClick={() => setTool(null)}>{activeTool.shortTitle}×</Button>}
        <Button className="send" onClick={submit}>发送</Button>
      </View>
    </View>
  );
}
