import { useState } from "react";
import { Button, Text, Textarea, View } from "@tarojs/components";
import {
  buildGlobalDharmaChecklist,
  createDachengId,
  dachengBrand,
  dachengHeroChips,
  dachengToolEntries,
  globalDharmaStartMessage,
  makeDachengFlashcards,
  nextDachengFlashcardDue,
  remnoteInspiredFlashcardPrinciples,
  type DachengFlashcard,
  type DachengRating,
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

const ratingLabels: DachengRating[] = ["Again", "Hard", "Good", "Easy"];

export default function IndexPage() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [tool, setTool] = useState<DachengToolId | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [logs, setLogs] = useState<string[]>([]);
  const [cards, setCards] = useState<DachengFlashcard[]>([]);
  const [cardIndex, setCardIndex] = useState(0);
  const [showAnswer, setShowAnswer] = useState(false);
  const activeTool = dachengToolEntries.find((item) => item.id === tool) ?? null;
  const activeCard = cards[cardIndex] ?? null;

  function add(role: Role, text: string, tag?: string) {
    setMessages((items) => [...items, { id: createDachengId("mp-msg"), role, text, tag }]);
  }

  function choosePrompt(prompt: string, nextTool?: DachengToolId) {
    setInput(prompt);
    setTool(nextTool ?? null);
    setMenuOpen(false);
  }

  function runGlobalDharma(text: string) {
    const checklist = buildGlobalDharmaChecklist(text);
    setLogs(checklist.map((item) => `✓ ${item.label}`));
    add("assistant", globalDharmaStartMessage("mini"), "全球法布施");
    add("assistant", `全球法布施完成：已整理 ${checklist.length} 个地区。`, "全球法布施");
  }

  function makeDeck(text: string) {
    const nextCards = makeDachengFlashcards(text);
    setCards((items) => [...nextCards, ...items]);
    setCardIndex(0);
    setShowAnswer(false);
    add(
      "assistant",
      nextCards.length ? `已制作 ${nextCards.length} 张背诵闪卡。` : "内容太短，请补充正文后再制卡。",
      "背诵闪卡",
    );
  }

  function submit() {
    const text = input.trim() || dachengBrand.defaultText;
    setInput("");
    add("user", text, activeTool?.title);
    if (tool === "global-dharma") runGlobalDharma(text);
    else if (tool === "flashcards") makeDeck(text);
    else add("assistant", "已收到。可以继续输入，或点 + 进入全球法布施和背诵闪卡。");
  }

  function review(rating: DachengRating) {
    if (!activeCard) return;
    setCards((items) =>
      items.map((card) =>
        card.id === activeCard.id
          ? { ...card, reviews: card.reviews + 1, due: nextDachengFlashcardDue(rating) }
          : card,
      ),
    );
    setCardIndex((index) => (cards.length ? (index + 1) % cards.length : 0));
    setShowAnswer(false);
  }

  return (
    <View className={messages.length ? "page has-chat" : "page"}>
      <View className="bg" />
      <View className="topbar">
        <Text className="brand">{dachengBrand.name}</Text>
        <Button className="login">登录</Button>
      </View>

      {!messages.length && (
        <View className="hero">
          <Text className="title">{dachengBrand.greeting}</Text>
          <Text className="subtitle">{dachengBrand.tagline}</Text>
          <View className="chips">
            {dachengHeroChips.map((chip) => (
              <Button className="chip" key={chip.id} onClick={() => choosePrompt(chip.prompt, chip.tool)}>
                <Text className="chip-icon">{chip.icon}</Text>
                <Text>{chip.label}</Text>
              </Button>
            ))}
          </View>
        </View>
      )}

      <View className="messages">
        {messages.map((message) => (
          <View className={`message ${message.role}`} key={message.id}>
            <Text className="avatar">{message.role === "user" ? "我" : dachengBrand.name.slice(0, 1)}</Text>
            <Text className="bubble">{message.tag ? `${message.tag}：` : ""}{message.text}</Text>
          </View>
        ))}
      </View>

      <View className="side-panels">
        <View className="panel">
          <Text className="panel-title">全球法布施</Text>
          <Text className="panel-copy">小程序只保留首页轻量流程，不显示 App 专属页面。</Text>
          {(logs.length ? logs : ["等待输入正文后生成全球法布施清单。"])
            .map((line) => <Text className="log" key={line}>{line}</Text>)}
        </View>
        <View className="panel">
          <Text className="panel-title">背诵闪卡</Text>
          <Text className="panel-copy">{cards.length ? `${cards.length} 张卡片` : "暂无卡片"}</Text>
          {activeCard ? (
            <View className="flashcard">
              <Text className="card-kind">{activeCard.kind} · {activeCard.due} · 已复习 {activeCard.reviews} 次</Text>
              <Text className="card-front">{activeCard.front}</Text>
              {showAnswer ? <Text className="card-back">{activeCard.back}</Text> : <Button onClick={() => setShowAnswer(true)}>显示答案</Button>}
              <View className="reviews">
                {ratingLabels.map((rating) => <Button key={rating} onClick={() => review(rating)}>{rating}</Button>)}
              </View>
            </View>
          ) : (
            <Text className="panel-copy">选择背诵闪卡后会自动生成挖空卡和双向卡。</Text>
          )}
          {remnoteInspiredFlashcardPrinciples.map((item) => <Text className="principle" key={item}>• {item}</Text>)}
        </View>
      </View>

      {menuOpen && (
        <View className="menu">
          {dachengToolEntries.map((item) => (
            <View className="menu-item" key={item.id} onClick={() => { setTool(item.id); setMenuOpen(false); }}>
              <Text className="menu-icon">{item.icon}</Text>
              <View>
                <Text className="menu-title">{item.title}</Text>
                <Text className="menu-copy">{item.description}</Text>
              </View>
            </View>
          ))}
        </View>
      )}

      <View className="composer">
        <Button className="plus" onClick={() => setMenuOpen(!menuOpen)}>+</Button>
        <Textarea
          className="input"
          value={input}
          maxlength={1800}
          autoHeight
          onInput={(event) => setInput(event.detail.value)}
          placeholder={activeTool ? `${activeTool.action}，也可以继续问一问${dachengBrand.name}` : dachengBrand.inputPlaceholder}
        />
        {activeTool && <Button className="mode" onClick={() => setTool(null)}>{activeTool.shortTitle}×</Button>}
        <Button className="send" onClick={submit}>➤</Button>
      </View>
    </View>
  );
}
