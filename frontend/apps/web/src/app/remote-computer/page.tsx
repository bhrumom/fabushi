"use client";

import { FormEvent, PointerEvent as ReactPointerEvent, useEffect, useMemo, useRef, useState } from "react";
import type { ComputerAction, ComputerPoint } from "../../lib/mahayana-host/contracts";
import { MobileRemoteComputerPeer, type MobilePeerState, type RemoteFrame } from "../../lib/remote-computer/mobile-peer";
import { RemoteComputerApi, type PairedClientRecord, type RemoteAuthSession, type RemoteComputerInfo } from "../../lib/remote-computer/remote-api";
import styles from "./remote-computer.module.css";

type PointerMode = "single" | "double" | "right" | "scroll";

interface PointerGesture {
  pointerId: number;
  start: ComputerPoint;
  last: ComputerPoint;
  path: ComputerPoint[];
}

function formatRelativeOnline(computer: RemoteComputerInfo): string {
  if (computer.online) return "在线";
  const seconds = Math.max(0, Math.floor(Date.now() / 1000) - computer.lastSeenAt);
  if (seconds < 120) return "刚刚离线";
  if (seconds < 3600) return `${Math.floor(seconds / 60)} 分钟前`;
  if (seconds < 86_400) return `${Math.floor(seconds / 3600)} 小时前`;
  return `${Math.floor(seconds / 86_400)} 天前`;
}

function pointDistance(a: ComputerPoint, b: ComputerPoint): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

export default function RemoteComputerPage() {
  const api = useMemo(() => new RemoteComputerApi(), []);
  const [auth, setAuth] = useState<RemoteAuthSession | null>(() => api.currentSession());
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [loginBusy, setLoginBusy] = useState(false);
  const [pairingCode, setPairingCode] = useState("");
  const [phoneLabel, setPhoneLabel] = useState("我的手机");
  const [computers, setComputers] = useState<RemoteComputerInfo[]>([]);
  const [paired, setPaired] = useState<Record<string, PairedClientRecord>>(() => api.pairedClients());
  const [selectedDeviceId, setSelectedDeviceId] = useState("");
  const [peerState, setPeerState] = useState<MobilePeerState>({ phase: "idle" });
  const [frame, setFrame] = useState<RemoteFrame | null>(null);
  const [mode, setMode] = useState<PointerMode>("single");
  const [text, setText] = useState("");
  const [aiPrompt, setAiPrompt] = useState("");
  const [aiStatus, setAiStatus] = useState<string | null>(null);
  const [boundAgentId, setBoundAgentId] = useState<string | undefined>();
  const [error, setError] = useState<string | null>(null);
  const peerRef = useRef<MobileRemoteComputerPeer | null>(null);
  const connectionAttemptRef = useRef(0);
  const gestureRef = useRef<PointerGesture | null>(null);
  const imageRef = useRef<HTMLImageElement | null>(null);

  const selectedComputer = computers.find((computer) => computer.deviceId === selectedDeviceId);
  const connected = peerState.phase === "connected";

  const refreshComputers = async () => {
    const next = await api.listComputers();
    setComputers(next);
    const records = api.pairedClients();
    setPaired(records);
    setSelectedDeviceId((current) => {
      if (current && next.some((computer) => computer.deviceId === current)) return current;
      return next.find((computer) => records[computer.deviceId])?.deviceId ?? "";
    });
  };

  useEffect(() => {
    if (!auth) return;
    void refreshComputers().catch((cause) => setError(cause instanceof Error ? cause.message : String(cause)));
    const timer = window.setInterval(() => {
      void refreshComputers().catch((cause) => setError(cause instanceof Error ? cause.message : String(cause)));
    }, 20_000);
    return () => window.clearInterval(timer);
  }, [auth]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => () => {
    connectionAttemptRef.current += 1;
    const peer = peerRef.current;
    peerRef.current = null;
    void peer?.disconnect();
  }, []);

  useEffect(() => {
    const value = new URL(window.location.href).searchParams.get("agentId")?.trim();
    if (value) setBoundAgentId(value.slice(0, 200));
  }, []);

  useEffect(() => {
    if (!connected) return;
    const timer = window.setInterval(() => {
      try { peerRef.current?.requestSnapshot(); } catch { /* connection state will surface separately */ }
    }, 850);
    return () => window.clearInterval(timer);
  }, [connected]);

  const login = async (event: FormEvent) => {
    event.preventDefault();
    setLoginBusy(true);
    setError(null);
    try {
      const session = await api.login(username, password);
      setAuth(session);
      setPassword("");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    } finally {
      setLoginBusy(false);
    }
  };

  const pairComputer = async () => {
    setError(null);
    try {
      const result = await api.pair(pairingCode, phoneLabel);
      setPairingCode("");
      setPaired(api.pairedClients());
      setSelectedDeviceId(result.deviceId);
      await refreshComputers();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    }
  };

  const connect = async (deviceId: string) => {
    const record = paired[deviceId];
    if (!record) {
      setError("这台电脑还没有与本手机配对");
      return;
    }
    const attempt = connectionAttemptRef.current + 1;
    connectionAttemptRef.current = attempt;
    const previous = peerRef.current;
    peerRef.current = null;
    setError(null);
    setAiStatus(null);
    setFrame(null);
    setSelectedDeviceId(deviceId);
    setPeerState({ phase: "connecting" });
    if (previous) await previous.disconnect();
    if (connectionAttemptRef.current !== attempt) return;

    let peer: MobileRemoteComputerPeer | null = null;
    const isCurrent = () => peer !== null && connectionAttemptRef.current === attempt && peerRef.current === peer;
    peer = new MobileRemoteComputerPeer({
      api,
      deviceId,
      clientId: record.clientId,
      clientToken: record.clientToken,
      onState: (state) => { if (isCurrent()) setPeerState(state); },
      onFrame: (nextFrame) => { if (isCurrent()) setFrame(nextFrame); },
      onError: (message) => { if (isCurrent()) setError(message); },
      onAiAck: (accepted, message) => {
        if (!isCurrent()) return;
        setAiStatus(accepted ? "AI 已接收任务，执行过程会显示在上方屏幕中。" : null);
        if (!accepted) setError(message || "AI 任务未被桌面端接受");
      },
    });
    peerRef.current = peer;
    try {
      await peer.connect();
      if (!isCurrent()) await peer.disconnect();
    } catch (cause) {
      if (isCurrent()) {
        setError(cause instanceof Error ? cause.message : String(cause));
        setPeerState((current) => ({ ...current, phase: "failed" }));
      }
    }
  };

  const disconnect = async () => {
    connectionAttemptRef.current += 1;
    const peer = peerRef.current;
    peerRef.current = null;
    if (peer) await peer.disconnect();
    setPeerState({ phase: "closed" });
    setFrame(null);
    setAiStatus(null);
  };

  const logout = async () => {
    await disconnect();
    api.logout();
    setAuth(null);
    setComputers([]);
    setPaired({});
    setSelectedDeviceId("");
    setError(null);
  };

  const sendAction = (action: ComputerAction, then: ComputerAction[] = []) => {
    try {
      const peer = peerRef.current;
      if (!peer || !connected) throw new Error("远程控制通道尚未连接");
      peer.sendAction(action, then);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    }
  };

  const sourcePoint = (event: ReactPointerEvent<HTMLImageElement>): ComputerPoint | null => {
    const image = imageRef.current;
    if (!image || !frame) return null;
    const bounds = image.getBoundingClientRect();
    if (bounds.width <= 0 || bounds.height <= 0) return null;
    const sourceWidth = frame.width ?? image.naturalWidth;
    const sourceHeight = frame.height ?? image.naturalHeight;
    if (!sourceWidth || !sourceHeight) return null;
    return {
      x: Math.max(0, Math.min(sourceWidth - 1, Math.round((event.clientX - bounds.left) / bounds.width * sourceWidth))),
      y: Math.max(0, Math.min(sourceHeight - 1, Math.round((event.clientY - bounds.top) / bounds.height * sourceHeight))),
    };
  };

  const pointerDown = (event: ReactPointerEvent<HTMLImageElement>) => {
    if (!connected) return;
    const point = sourcePoint(event);
    if (!point) return;
    event.preventDefault();
    event.currentTarget.setPointerCapture(event.pointerId);
    gestureRef.current = { pointerId: event.pointerId, start: point, last: point, path: [point] };
  };

  const pointerMove = (event: ReactPointerEvent<HTMLImageElement>) => {
    const gesture = gestureRef.current;
    if (!gesture || gesture.pointerId !== event.pointerId) return;
    const point = sourcePoint(event);
    if (!point || pointDistance(point, gesture.last) < 6) return;
    gesture.last = point;
    if (gesture.path.length < 80) gesture.path.push(point);
  };

  const pointerUp = (event: ReactPointerEvent<HTMLImageElement>) => {
    const gesture = gestureRef.current;
    if (!gesture || gesture.pointerId !== event.pointerId) return;
    gestureRef.current = null;
    try { event.currentTarget.releasePointerCapture(event.pointerId); } catch { /* pointer may already be released */ }
    const end = sourcePoint(event) ?? gesture.last;
    const distance = pointDistance(gesture.start, end);
    if (mode === "scroll") {
      const dx = end.x - gesture.start.x;
      const dy = end.y - gesture.start.y;
      if (Math.max(Math.abs(dx), Math.abs(dy)) < 10) return;
      const horizontal = Math.abs(dx) > Math.abs(dy);
      const direction = horizontal
        ? dx > 0 ? "right" : "left"
        : dy > 0 ? "down" : "up";
      const amount = Math.max(1, Math.min(18, Math.round(Math.max(Math.abs(dx), Math.abs(dy)) / 45)));
      sendAction({ action: "scroll", x: gesture.start.x, y: gesture.start.y, direction, amount, description: "Phone scroll gesture" });
      return;
    }
    if (distance >= 12) {
      const path = [...gesture.path];
      if (pointDistance(path[path.length - 1], end) >= 2) path.push(end);
      sendAction({ action: "drag", path, button: mode === "right" ? "right" : "left", description: "Phone drag gesture" });
      return;
    }
    sendAction({
      action: "click",
      x: end.x,
      y: end.y,
      button: mode === "right" ? "right" : "left",
      count: mode === "double" ? 2 : 1,
      description: mode === "double" ? "Phone double click" : mode === "right" ? "Phone right click" : "Phone click",
    });
  };

  const typeText = () => {
    if (!text) return;
    sendAction({ action: "type", text, description: "Text typed from paired phone" });
    setText("");
  };

  const sendAiPrompt = () => {
    const prompt = aiPrompt.trim();
    if (!prompt) return;
    try {
      const peer = peerRef.current;
      if (!peer || !connected) throw new Error("远程控制通道尚未连接");
      peer.sendAiRequest(prompt, boundAgentId);
      setAiPrompt("");
      setAiStatus("正在把任务交给这台电脑上的 AI…");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    }
  };

  if (!auth) {
    return (
      <main className={styles.shell}>
        <section className={styles.loginCard}>
          <div className={styles.brandMark}>乘</div>
          <h1>远程控制我的电脑</h1>
          <p>登录与电脑相同的 Fabushi 账号。密码只用于创建本设备的账号会话，不会发送给被控电脑。</p>
          <form onSubmit={login}>
            <label><span>用户名 / 邮箱 / 手机号</span><input autoComplete="username" value={username} onChange={(event) => setUsername(event.target.value)} /></label>
            <label><span>密码</span><input type="password" autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} /></label>
            <button type="submit" disabled={loginBusy || !username.trim() || !password}>{loginBusy ? "正在登录…" : "登录"}</button>
          </form>
          {error ? <p className={styles.error}>{error}</p> : null}
        </section>
      </main>
    );
  }

  return (
    <main className={styles.shell}>
      <header className={styles.topbar}>
        <div><strong>这台电脑</strong><small>{connected ? `已连接 · ${selectedComputer?.label ?? "电脑"}` : "手机远程控制"}</small></div>
        <div><span data-live={connected ? "true" : "false"}>{connected ? "LIVE" : peerState.phase.toUpperCase()}</span><button type="button" onClick={() => void logout()}>退出</button></div>
      </header>

      {!connected ? (
        <section className={styles.setup}>
          <section className={styles.card}>
            <h2>授权控制电脑</h2>
            <p>安装并登录桌面应用后，电脑会自动显示在下方。首次控制仍需在电脑资料栏打开远控并输入 12 位配对码。</p>
            <label><span>这部手机的名称</span><input value={phoneLabel} onChange={(event) => setPhoneLabel(event.target.value)} maxLength={80} /></label>
            <div className={styles.pairRow}>
              <input value={pairingCode} onChange={(event) => setPairingCode(event.target.value.toUpperCase().replace(/[^0-9A-F]/g, "").slice(0, 12))} placeholder="AB12CD34EF56" inputMode="text" autoCapitalize="characters" />
              <button type="button" disabled={pairingCode.length !== 12} onClick={() => void pairComputer()}>配对</button>
            </div>
          </section>

          <section className={styles.card}>
            <div className={styles.cardHeader}><h2>我的电脑</h2><button type="button" onClick={() => void refreshComputers()}>刷新</button></div>
            <div className={styles.computerList}>
              {computers.map((computer) => {
                const authorized = Boolean(paired[computer.deviceId]);
                return (
                  <button
                    key={computer.deviceId}
                    type="button"
                    onClick={() => {
                      if (authorized) void connect(computer.deviceId);
                      else setError("这台电脑已在线；请先输入其资料栏显示的 12 位配对码完成首次授权。");
                    }}
                    disabled={!computer.online}
                  >
                    <span className={styles.computerIcon}>⌘</span>
                    <span><strong>{computer.label}</strong><small data-online={computer.online ? "true" : "false"}>{formatRelativeOnline(computer)}</small></span>
                    <em>{!computer.online ? "离线" : authorized ? "连接" : "待授权"}</em>
                  </button>
                );
              })}
              {!computers.length ? <p>尚未发现电脑。请先在电脑上安装并登录 Fabushi。</p> : null}
            </div>
          </section>
          {error ? <p className={styles.error}>{error}</p> : null}
        </section>
      ) : (
        <section className={styles.remoteStage}>
          <section className={styles.screenCard}>
            <div className={styles.screenViewport} data-mode={mode}>
              {frame ? (
                <img
                  ref={imageRef}
                  src={frame.dataUrl}
                  alt="远程电脑屏幕"
                  draggable={false}
                  onPointerDown={pointerDown}
                  onPointerMove={pointerMove}
                  onPointerUp={pointerUp}
                  onPointerCancel={() => { gestureRef.current = null; }}
                />
              ) : <div className={styles.loadingScreen}><i /><span>正在读取电脑屏幕…</span></div>}
            </div>
            <div className={styles.modeBar}>
              <button type="button" data-active={mode === "single"} onClick={() => setMode("single")}>点击</button>
              <button type="button" data-active={mode === "double"} onClick={() => setMode("double")}>双击</button>
              <button type="button" data-active={mode === "right"} onClick={() => setMode("right")}>右键</button>
              <button type="button" data-active={mode === "scroll"} onClick={() => setMode("scroll")}>滚动</button>
              <button type="button" onClick={() => peerRef.current?.requestSnapshot()}>刷新</button>
            </div>
          </section>

          <section className={styles.keyboardCard}>
            <div className={styles.aiRow}>
              <div><strong>让 AI 操作</strong><small>任务在这台电脑上运行，仍遵守本机权限和操作审批。{boundAgentId ? ` 当前绑定 Bot：${boundAgentId}` : ""}</small></div>
              <div className={styles.textRow}>
                <input
                  value={aiPrompt}
                  onChange={(event) => setAiPrompt(event.target.value)}
                  maxLength={20_000}
                  onKeyDown={(event) => { if (event.key === "Enter") { event.preventDefault(); sendAiPrompt(); } }}
                  placeholder="例如：打开浏览器，把今天的资料整理进文档…"
                />
                <button type="button" disabled={!aiPrompt.trim()} onClick={sendAiPrompt}>交给 AI</button>
              </div>
              {aiStatus ? <small className={styles.aiStatus}>{aiStatus}</small> : null}
            </div>
            <div className={styles.manualLabel}><strong>人工操作</strong><small>直接把文字或按键发送到当前桌面。</small></div>
            <div className={styles.textRow}>
              <input value={text} maxLength={20_000} onChange={(event) => setText(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") { event.preventDefault(); typeText(); } }} placeholder="输入文字到电脑…" />
              <button type="button" disabled={!text} onClick={typeText}>输入</button>
            </div>
            <div className={styles.keyGrid}>
              {["Return", "Tab", "Escape", "Backspace", "Left", "Up", "Down", "Right"].map((key) => (
                <button key={key} type="button" onClick={() => sendAction({ action: "key", key, description: `Phone key ${key}` })}>{key === "Return" ? "↵" : key === "Backspace" ? "⌫" : key === "Escape" ? "Esc" : key === "Left" ? "←" : key === "Right" ? "→" : key === "Up" ? "↑" : key === "Down" ? "↓" : key}</button>
              ))}
              <button type="button" onClick={() => sendAction({ action: "key", key: "primary+a", description: "Phone Select All" })}>⌘/Ctrl A</button>
              <button type="button" onClick={() => sendAction({ action: "key", key: "primary+c", description: "Phone Copy" })}>⌘/Ctrl C</button>
              <button type="button" onClick={() => sendAction({ action: "key", key: "primary+v", description: "Phone Paste" })}>⌘/Ctrl V</button>
              <button type="button" onClick={() => sendAction({ action: "key", key: "primary+z", description: "Phone Undo" })}>⌘/Ctrl Z</button>
            </div>
          </section>

          <footer className={styles.remoteFooter}>
            <span><i /> 端到端 WebRTC · {peerState.peerState ?? "connected"}</span>
            <button type="button" onClick={() => void disconnect()}>断开远控</button>
          </footer>
          {error ? <p className={styles.error}>{error}</p> : null}
        </section>
      )}
    </main>
  );
}
