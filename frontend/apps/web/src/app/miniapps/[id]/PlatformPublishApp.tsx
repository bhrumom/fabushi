"use client";

import React, { useState } from "react";
import "./miniapps.css";

export default function PlatformPublishApp() {
  const [title, setTitle] = useState("测试文章标题");
  const [text, setText] = useState("");
  const [platform, setPlatform] = useState("wechat");
  const [running, setRunning] = useState(false);
  const [deployTaskId, setDeployTaskId] = useState<string | null>(null);

  const handleTestLocalExecution = async () => {
    if (!window.FabushiMiniApp) {
      alert("SDK 尚未就绪");
      return;
    }
    
    setRunning(true);
    
    // 1. Write File (Testing Unrestricted Path)
    // We'll write to a relatively safe absolute path on Mac: ~/Documents
    // Note: JS doesn't natively know ~ so we just use the user-provided generic path.
    // We'll just pass a generic name, the JS bridge currently uses getApplicationDocumentsDirectory() internally 
    // unless p.isAbsolute(path) is true. We'll pass an absolute path to test.
    const scriptPath = "/tmp/fabushi_publish_test_script.js"; 
    
    const scriptContent = `
      console.log("==========================================");
      console.log("[Playwright CLI / 自动化流水线] 已接管进程");
      console.log("==========================================");
      console.log("正在解析发布清单...");
      console.log("-> 目标平台: ${platform}");
      console.log("-> 稿件标题: ${title}");
      console.log("-> 稿件长度: ${text.length} 字符");
      
      let progress = 0;
      const interval = setInterval(() => {
        progress += 25;
        console.log("[" + new Date().toISOString() + "] 部署进度 " + progress + "%...");
        if (progress >= 100) {
          clearInterval(interval);
          console.log("✅ 发布任务已成功完成！");
        }
      }, 800);
    `;
    
    try {
      const fsRes = await window.FabushiMiniApp.invoke("fs.writeFile", {
        path: scriptPath,
        content: scriptContent
      });
      if (!fsRes.ok) throw new Error(fsRes.message);
      
      // 2. Shell Execute
      // We pass it to the host, the host will create a Chat component and stream logs!
      const shellRes = await window.FabushiMiniApp.invoke("shell.execute", {
        title: `部署流水线 (${platform})`,
        command: "node",
        arguments: [fsRes.path]
      });
      
      if (!shellRes.ok) {
         // It might fail, but logs are in the chat anyway
      }
      setDeployTaskId(Date.now().toString()); // Just to show state change

    } catch (e: any) {
      alert(`流水线异常中断: ${e.message}`);
    } finally {
      setRunning(false);
    }
  };

  return (
    <div className="ma-container" style={{ padding: 0, display: "flex", height: "100vh", overflow: "hidden" }}>
      {/* Sidebar */}
      <div style={{ 
        width: 240, 
        background: "#1C2433", 
        borderRight: "1px solid #263445",
        padding: "24px 16px"
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 32 }}>
          <div style={{ width: 32, height: 32, borderRadius: 8, background: "linear-gradient(135deg, #FF9F43, #E67E22)", display: "flex", alignItems: "center", justifyContent: "center" }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.5"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="17 8 12 3 7 8"></polyline><line x1="12" y1="3" x2="12" y2="15"></line></svg>
          </div>
          <span style={{ fontSize: 18, fontWeight: 800, color: "#fff" }}>Publish Platform</span>
        </div>

        <div style={{ fontSize: 12, color: "#91A3B7", fontWeight: 700, textTransform: "uppercase", letterSpacing: 1, marginBottom: 12 }}>部署目标</div>
        <div 
          onClick={() => setPlatform("wechat")}
          style={{ padding: "10px 14px", borderRadius: 8, background: platform === "wechat" ? "rgba(255,159,67,0.1)" : "transparent", color: platform === "wechat" ? "#FF9F43" : "#91A3B7", cursor: "pointer", fontWeight: 600, marginBottom: 4 }}
        >
          WeChat 公众号
        </div>
        <div 
          onClick={() => setPlatform("xiaohongshu")}
          style={{ padding: "10px 14px", borderRadius: 8, background: platform === "xiaohongshu" ? "rgba(255,159,67,0.1)" : "transparent", color: platform === "xiaohongshu" ? "#FF9F43" : "#91A3B7", cursor: "pointer", fontWeight: 600, marginBottom: 4 }}
        >
          Xiaohongshu 小红书
        </div>
        <div 
          onClick={() => setPlatform("zhihu")}
          style={{ padding: "10px 14px", borderRadius: 8, background: platform === "zhihu" ? "rgba(255,159,67,0.1)" : "transparent", color: platform === "zhihu" ? "#FF9F43" : "#91A3B7", cursor: "pointer", fontWeight: 600 }}
        >
          Zhihu 知乎
        </div>
      </div>

      {/* Main Content */}
      <div style={{ flex: 1, padding: "32px 40px", overflowY: "auto", background: "#0B111A" }}>
        <div style={{ maxWidth: 800 }}>
          <h1 style={{ fontSize: 28, fontWeight: 800, margin: "0 0 8px 0" }}>Create Draft</h1>
          <p style={{ color: "#91A3B7", marginBottom: 32 }}>配置并生成您的多平台发布草稿，准备进行底层 Playwright 自动化调度。</p>

          <div style={{ background: "#17212B", border: "1px solid #263445", borderRadius: 12, padding: 24 }}>
            <label className="ma-label" style={{ fontSize: 13, textTransform: "uppercase", letterSpacing: 0.5 }}>Draft Title</label>
            <input 
              style={{
                width: "100%", background: "#0B111A", border: "1px solid #263445",
                borderRadius: "8px", padding: "12px 16px", color: "#fff", marginBottom: "24px",
                fontFamily: "inherit", fontSize: "15px", boxSizing: "border-box",
                transition: "border-color 0.2s"
              }}
              value={title}
              onChange={(e) => setTitle(e.target.value)}
            />

            <label className="ma-label" style={{ fontSize: 13, textTransform: "uppercase", letterSpacing: 0.5 }}>Markdown Body</label>
            <textarea
              style={{
                width: "100%", background: "#0B111A", border: "1px solid #263445",
                borderRadius: "8px", padding: "16px", color: "#fff", marginBottom: "24px",
                fontFamily: "inherit", fontSize: "15px", boxSizing: "border-box",
                minHeight: 200, resize: "vertical"
              }}
              placeholder="Start writing or paste markdown here..."
              value={text}
              onChange={(e) => setText(e.target.value)}
            />

            {deployTaskId ? (
              <div style={{ background: "rgba(76, 175, 122, 0.1)", border: "1px solid rgba(76, 175, 122, 0.3)", borderRadius: 8, padding: 16, display: "flex", alignItems: "center", gap: 12 }}>
                <div style={{ width: 12, height: 12, borderRadius: "50%", background: "#4CAF7A", boxShadow: "0 0 10px #4CAF7A" }} />
                <div>
                  <div style={{ color: "#4CAF7A", fontWeight: 700 }}>部署任务已挂起并发送至宿主</div>
                  <div style={{ color: "#91A3B7", fontSize: 13, marginTop: 4 }}>请将本面板下滑收起，在机器人聊天流中查看实时的终端日志更新。</div>
                </div>
              </div>
            ) : (
              <div style={{ display: "flex", justifyContent: "flex-end" }}>
                <button 
                  className="ma-btn" 
                  onClick={handleTestLocalExecution} 
                  disabled={running}
                  style={{ width: "auto", "--accent-start": "#FF9F43", "--accent-end": "#E67E22" } as any}
                >
                  {running ? "Dispatching..." : "Deploy to Platform"}
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
