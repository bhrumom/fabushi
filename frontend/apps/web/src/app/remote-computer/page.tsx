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
  const [error, setError] = useState<string | null>(null);
  const peerRef = useRef<MobileRemoteComputerPeer | null>(null);
  const gestureRef = useRef<PointerGesture | null>(null);
  const imageRef = useRef<HTMLImageElement | null>(null);

  const pairedComputers = computers.filter((computer) => paired[computer.deviceId]);
  const selectedComputer = computers.find((computer) => computer.deviceId === selectedDeviceId);
  const connected = peerState.phase === "connected";

  const refreshComputers = async () => {
    const next = await api.listComputers();
    setComputers(next);
    const records = api.pairedClients();
    setPaired(records);
    if (!selectedDeviceId) {
      const firstPaired = next.find((computer) => records[computer.deviceId]);
      if (firstPaired) setSelectedDeviceId(firstPaired.deviceId);
    }
  };

  useEffect(() => {
    if (!auth) return;
    void refreshComputers().catch((cause) => setError(cause instanceof Error ? cause.message : String(cause)));
  }, [auth]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => () => {
    void peerRef.current?.disconnect();
    peerRef.current = null;
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
    setError(null);
    setSelectedDeviceId(deviceId);
    await peerRef.current?.disconnect();
    const peer = new MobileRemoteComputerPeer({
      api,
      deviceId,
      clientId: record.clientId,
      onState: setPeerState,
      onFrame: setFrame,
      onError: setError,
    });
    peerRef.current = peer;
    try {
      await peer.connect();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
      setPeerState((current) => ({ ...current, phase: "failed" }));
    }
  };

  const disconnect = async () => {
    const peer = peerRef.current;
    peerRef.current = null;
    if (peer) await peer.disconnect();
    setPeerState({ phase: "closed" });
    setFrame(null);
  };

  const logout = async () => {
    await disconnect();
    api.logout();
    setAuth(null);
    setComputers([]);
  };

  const sendAction = (action: ComputerAction, then: ComputerAction[] = []) => {
    try {
      peerRef.current?.sendAction(action, then);
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

  if (!auth) {
    return (
      <main className={styles.shell}>
        <section className={styles.loginCard}>
          <div className={styles.brandMark}>乘</div>
          <h1>远程控制我的电脑</h1>
          <p>登录与 Mac 相同的大乘账号。密码只用于创建本手机的账号会话，不会发送给被控电脑。</p>
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
        <div><strong>这台电脑</strong><small>{connected ? `已连接 · ${selectedComputer?.label ?? "Mac"}` : "手机远程控制"}</small></div>
        <div><span data-live={connected ? "true" : "false"}>{connected ? "LIVE" : peerState.phase.toUpperCase()}</span><button type="button" onClick={() => void logout()}>退出</button></div>
      </header>

      {!connected ? (
        <section className={styles.setup}>
          <section className={styles.card}>
            <h2>配对新的 Mac</h2>
            <p>在 Mac 的「这台电脑 → 手机远程控制」打开远控并找到 8 位配对码。</p>
            <label><span>这部手机的名称</span><input value={phoneLabel} onChange={(event) => setPhoneLabel(event.target.value)} maxLength={80} /></label>
            <div className={styles.pairRow}>
              <input value={pairingCode} onChange={(event) => setPairingCode(event.target.value.toUpperCase().replace(/[^0-9A-F]/g, "").slice(0, 8))} placeholder="AB12CD34" inputMode="text" autoCapitalize="characters" />
              <button type="button" disabled={pairingCode.length !== 8} onClick={() => void pairComputer()}>配对</button>
            </div>
          </section>

          <section className={styles.card}>
            <div className={styles.cardHeader}><h2>我的电脑</h2><button type="button" onClick={() => void refreshComputers()}>刷新</button></div>
            <div className={styles.computerList}>
              {pairedComputers.map((computer) => (
                <button key={computer.deviceId} type="button" onClick={() => void connect(computer.deviceId)} disabled={!computer.online}>
                  <span className={styles.computerIcon}>⌘</span>
                  <span><strong>{computer.label}</strong><small data-online={computer.online ? "true" : "false"}>{formatRelativeOnline(computer)}</small></span>
                  <em>{computer.online ? "连接" : "离线"}</em>
                </button>
              ))}
              {!pairedComputers.length ? <p>还没有这部手机已配对的电脑。</p> : null}
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
                  alt="远程 Mac 屏幕"
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
            <div className={styles.textRow}>
              <input value={text} onChange={(event) => setText(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") { event.preventDefault(); typeText(); } }} placeholder="输入文字到电脑…" />
              <button type="button" disabled={!text} onClick={typeText}>输入</button>
            </div>
            <div className={styles.keyGrid}>
              {["Return", "Tab", "Escape", "Backspace", "Left", "Up", "Down", "Right"].map((key) => (
                <button key={key} type="button" onClick={() => sendAction({ action: "key", key, description: `Phone key ${key}` })}>{key === "Return" ? "↵" : key === "Backspace" ? "⌫" : key === "Escape" ? "Esc" : key === "Left" ? "←" : key === "Right" ? "→" : key === "Up" ? "↑" : key === "Down" ? "↓" : key}</button>
              ))}
              <button type="button" onClick={() => sendAction({ action: "key", key: "command+a", description: "Phone Select All" })}>⌘A</button>
              <button type="button" onClick={() => sendAction({ action: "key", key: "command+c", description: "Phone Copy" })}>⌘C</button>
              <button type="button" onClick={() => sendAction({ action: "key", key: "command+v", description: "Phone Paste" })}>⌘V</button>
              <button type="button" onClick={() => sendAction({ action: "key", key: "command+z", description: "Phone Undo" })}>⌘Z</button>
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
