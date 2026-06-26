"use client";

import React, { useState } from "react";
import "./miniapps.css";

export default function FlashcardsApp() {
  const [text, setText] = useState("");
  const [mode, setMode] = useState("ai"); // 'ai' or 'random'
  const [logs, setLogs] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);
  const [bullets, setBullets] = useState<string[]>([""]);

  const log = (msg: string) => setLogs((prev) => [...prev, \`[\${new Date().toLocaleTimeString()}] \${msg}\`]);

  const handleCreate = async () => {
    const fullText = bullets.filter(b => b.trim()).join("\\n");
    if (!fullText) {
      log("请输入需要制卡的内容");
      return;
    }
    if (!window.FabushiMiniApp) {
      log("SDK 尚未就绪");
      return;
    }
    
    setLoading(true);
    log(\`正在使用 \${mode === 'ai' ? 'AI智能提取' : '随机挖空'} 模式制卡...\`);
    
    const res = await window.FabushiMiniApp.invoke("flashcards.createDeck", {
      title: "新闪卡集",
      text: fullText,
      mode: mode
    });
    
    if (res.ok) {
      log("制卡请求已发送给宿主聊天机器人，请在聊天框查看详细过程。");
    } else {
      log(\`宿主响应: \${res.message || "请求已发送"}\`);
    }
    setLoading(false);
  };

  const handleBulletChange = (index: number, value: string) => {
    const newBullets = [...bullets];
    newBullets[index] = value;
    setBullets(newBullets);
  };

  const handleKeyDown = (e: React.KeyboardEvent, index: number) => {
    if (e.key === "Enter") {
      e.preventDefault();
      const newBullets = [...bullets];
      newBullets.splice(index + 1, 0, "");
      setBullets(newBullets);
      // Let React render the new input then focus it
      setTimeout(() => {
        const nextInput = document.getElementById(\`bullet-\${index + 1}\`);
        nextInput?.focus();
      }, 0);
    } else if (e.key === "Backspace" && bullets[index] === "" && bullets.length > 1) {
      e.preventDefault();
      const newBullets = [...bullets];
      newBullets.splice(index, 1);
      setBullets(newBullets);
      setTimeout(() => {
        const prevInput = document.getElementById(\`bullet-\${index - 1}\`);
        prevInput?.focus();
      }, 0);
    }
  };

  return (
    <div className="ma-card ma-fade-in" style={{ "--accent-start": "#7E57C2", "--accent-end": "#5E35B1", "--accent-rgb": "126, 87, 194", background: "rgba(15, 23, 34, 0.9)" } as any}>
      <h1 className="ma-header-title">智能背诵闪卡</h1>
      <p className="ma-header-subtitle" style={{ marginBottom: 24, fontSize: 13 }}>RemNote 风格层级记忆编辑器。支持大纲式输入与 AI 自动提取。</p>

      <div className="ma-pill-selector">
        <div className={\`ma-pill \${mode === 'ai' ? 'active' : ''}\`} onClick={() => setMode('ai')}>✨ AI 知识点提取</div>
        <div className={\`ma-pill \${mode === 'random' ? 'active' : ''}\`} onClick={() => setMode('random')}>🎲 随机填空抽查</div>
      </div>

      <div style={{
        background: "rgba(255,255,255,0.02)", 
        borderRadius: 16, 
        padding: "20px 16px",
        border: "1px solid rgba(255,255,255,0.05)",
        marginBottom: 24,
        minHeight: 200
      }}>
        {bullets.map((bullet, index) => (
          <div key={index} style={{ display: "flex", alignItems: "flex-start", marginBottom: 8 }}>
            <div style={{ marginTop: 8, marginRight: 12, width: 6, height: 6, borderRadius: "50%", background: "#7E57C2", flexShrink: 0 }} />
            <div style={{ flex: 1, borderLeft: "1px solid rgba(126, 87, 194, 0.2)", paddingLeft: 12 }}>
              <input
                id={\`bullet-\${index}\`}
                style={{
                  width: "100%", background: "transparent", border: "none", color: "#E2E8F0", 
                  fontSize: 16, outline: "none", fontFamily: "inherit", lineHeight: 1.5
                }}
                placeholder={index === 0 ? "输入要背诵的经文或内容 (按 Enter 添加新段落)..." : ""}
                value={bullet}
                onChange={(e) => handleBulletChange(index, e.target.value)}
                onKeyDown={(e) => handleKeyDown(e, index)}
              />
            </div>
          </div>
        ))}
      </div>

      <button className="ma-btn" onClick={handleCreate} disabled={loading}>
        {loading ? (
          "卡片生成中..."
        ) : (
          <>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"></path><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"></path></svg>
            投递至记忆队列
          </>
        )}
      </button>

      {logs.length > 0 && (
        <div className="ma-log-box" style={{ background: "transparent", border: "1px dashed rgba(255,255,255,0.1)" }}>
          {logs.map((l, i) => <div key={i} style={{ color: "#A78BFA" }}>{l}</div>)}
        </div>
      )}
    </div>
  );
}
