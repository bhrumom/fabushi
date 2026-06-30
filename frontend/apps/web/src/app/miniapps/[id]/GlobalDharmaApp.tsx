"use client";

import React, { useEffect, useMemo, useRef, useState } from "react";
import { CircleStop, Globe, Link2, RefreshCw, Send, Sparkles } from "lucide-react";
import * as THREE from "three";
import { bootMiniApp, fbApp, hostErrorMessage } from "./miniapp-runtime";
import "./miniapps.css";

type RegionPreset = {
  id: string;
  label: string;
  global?: boolean;
  countryCodes?: string[];
  fieldEnergy?: boolean;
  localLoopback?: boolean;
};

const regionPresets: RegionPreset[] = [
  { id: "global", label: "全球", global: true, countryCodes: ["ALL"] },
  { id: "eastAsia", label: "东亚", global: true, countryCodes: ["CN", "JP", "KR", "MN", "TW", "HK", "MO"] },
  { id: "americas", label: "美洲", global: true, countryCodes: ["US", "CA", "MX", "BR", "AR", "CL", "PE"] },
  { id: "europe", label: "欧洲", global: true, countryCodes: ["GB", "FR", "DE", "IT", "ES", "NL", "SE"] },
  { id: "field", label: "本地场能", global: false, countryCodes: [], fieldEnergy: true },
  { id: "loopback", label: "本地转经轮", global: false, countryCodes: [], localLoopback: true },
];

const HIGH_ENERGY_PRODUCT = {
  productId: "zen_buddha_asset",
  title: "3D佛像素材",
  priceLabel: "¥33.00",
  amount: 33,
};
const HIGH_ENERGY_PURCHASE_KEY = "fabushi.official.global-dharma.purchase.zen_buddha_asset";

function isPaidPayment(payment: any) {
  const status = String(payment?.status || payment?.order?.status || payment?.resultStatus || "").toUpperCase();
  return payment?.paid === true || status === "PAID" || status === "SUCCESS" || status === "TRADE_SUCCESS" || status === "9000";
}

export default function GlobalDharmaApp() {
  const [text, setText] = useState("");
  const [status, setStatus] = useState<any>(null);
  const [regionId, setRegionId] = useState("global");
  const [loopEnabled, setLoopEnabled] = useState(false);
  const [highEnergyUnlocked, setHighEnergyUnlocked] = useState(false);
  const [selectedMaterial, setSelectedMaterial] = useState<any>(null);
  const [logs, setLogs] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  const earthRef = useRef<THREE.Mesh | null>(null);
  const particlesRef = useRef<THREE.Points | null>(null);
  const transferringRef = useRef(false);
  const selectedRegion = useMemo(
    () => regionPresets.find((item) => item.id === regionId) || regionPresets[0],
    [regionId],
  );

  const log = (msg: string) => setLogs((prev) => [...prev, `[${new Date().toLocaleTimeString()}] ${msg}`]);

  const readHighEnergyPurchase = async () => {
    try {
      const raw = await fbApp.storage.deviceStorage.getItem(HIGH_ENERGY_PURCHASE_KEY);
      if (!raw) return false;
      const record = JSON.parse(raw);
      return record?.productId === HIGH_ENERGY_PRODUCT.productId && record?.paid === true;
    } catch {
      return false;
    }
  };

  const saveHighEnergyPurchase = async (payment: any) => {
    const record = {
      productId: HIGH_ENERGY_PRODUCT.productId,
      title: HIGH_ENERGY_PRODUCT.title,
      priceLabel: HIGH_ENERGY_PRODUCT.priceLabel,
      paid: true,
      paidAt: new Date().toISOString(),
      payment,
    };
    await fbApp.storage.deviceStorage.setItem(HIGH_ENERGY_PURCHASE_KEY, JSON.stringify(record));
    setHighEnergyUnlocked(true);
  };

  useEffect(() => {
    transferringRef.current = Boolean(status?.isTransferring);
  }, [status?.isTransferring]);

  useEffect(() => {
    let active = true;
    const refresh = async () => {
      try {
        const unlocked = await readHighEnergyPurchase();
        if (active) setHighEnergyUnlocked(unlocked);
        const data = await fbApp.invoke<any>("dharma.getSendStatus");
        if (!active) return;
        setStatus(data);
        setSelectedMaterial(data?.selectedContent);
      } catch (error) {
        if (active) log(hostErrorMessage(error, "读取发送状态失败"));
      }
    };

    void bootMiniApp("official.global-dharma", "全球法布施").then(() => refresh());
    const unsubscribeReady = fbApp.on("ready", () => {
      void refresh();
    });
    return () => {
      active = false;
      unsubscribeReady();
    };
  }, []);

  const waitForPaymentConfirmation = async (invoice: any) => {
    for (let i = 0; i < 8; i += 1) {
      await new Promise((resolve) => window.setTimeout(resolve, i === 0 ? 600 : 2500));
      const queried = await fbApp.payments.queryInvoice(invoice);
      if (isPaidPayment(queried)) return queried;
    }
    return null;
  };

  const ensureHighEnergyPurchase = async () => {
    if (highEnergyUnlocked || await readHighEnergyPurchase()) {
      setHighEnergyUnlocked(true);
      return true;
    }
    log(`${HIGH_ENERGY_PRODUCT.title}需要购买，正在请求宿主支付能力。`);
    try {
      await fbApp.auth.requireLogin();
    } catch (error) {
      log(hostErrorMessage(error, "宿主登录能力不可用，将继续尝试支付。"));
    }

    const invoice = await fbApp.payments.createInvoice({
      sku: HIGH_ENERGY_PRODUCT.productId,
      productId: HIGH_ENERGY_PRODUCT.productId,
      title: HIGH_ENERGY_PRODUCT.title,
      subject: HIGH_ENERGY_PRODUCT.title,
      amount: HIGH_ENERGY_PRODUCT.amount,
      currency: "CNY",
      priceLabel: HIGH_ENERGY_PRODUCT.priceLabel,
      metadata: {
        miniAppId: "official.global-dharma",
        entitlement: HIGH_ENERGY_PRODUCT.productId,
      },
    });
    const payment = await fbApp.payments.openInvoice(invoice);
    if (isPaidPayment(payment)) {
      await saveHighEnergyPurchase(payment);
      log("支付成功，购买记录已由小程序 SDK 存储。后续可切换到后端 entitlement。");
      return true;
    }
    const confirmed = await waitForPaymentConfirmation(invoice);
    if (confirmed && isPaidPayment(confirmed)) {
      await saveHighEnergyPurchase(confirmed);
      log("支付成功，购买记录已由小程序 SDK 存储。后续可切换到后端 entitlement。");
      return true;
    }
    log("支付已发起，尚未确认成功。");
    return false;
  };

  useEffect(() => {
    if (!containerRef.current) return;

    const width = containerRef.current.clientWidth;
    const height = 280;
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 1000);
    camera.position.z = 2.7;

    const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true });
    renderer.setSize(width, height);
    renderer.setPixelRatio(window.devicePixelRatio);
    containerRef.current.appendChild(renderer.domElement);
    rendererRef.current = renderer;

    const geometry = new THREE.SphereGeometry(1, 64, 64);
    const material = new THREE.MeshBasicMaterial({
      color: 0x4CAF7A,
      wireframe: true,
      transparent: true,
      opacity: 0.3,
    });

    const earth = new THREE.Mesh(geometry, material);
    scene.add(earth);
    earthRef.current = earth;

    const particleGeo = new THREE.BufferGeometry();
    const particleCount = 1000;
    const posArray = new Float32Array(particleCount * 3);
    for (let i = 0; i < particleCount * 3; i += 1) {
      posArray[i] = (Math.random() - 0.5) * 2;
    }
    particleGeo.setAttribute("position", new THREE.BufferAttribute(posArray, 3));
    const particleMat = new THREE.PointsMaterial({
      size: 0.02,
      color: 0x88FFB4,
      transparent: true,
      opacity: 0,
    });
    const particles = new THREE.Points(particleGeo, particleMat);
    scene.add(particles);
    particlesRef.current = particles;

    let animationId: number;
    const animate = () => {
      animationId = requestAnimationFrame(animate);
      if (earthRef.current) {
        earthRef.current.rotation.y += 0.005;
        earthRef.current.rotation.x += 0.002;
      }
      if (particlesRef.current && transferringRef.current) {
        particlesRef.current.rotation.y -= 0.01;
        (particlesRef.current.material as THREE.PointsMaterial).opacity = 0.5 + Math.sin(Date.now() * 0.005) * 0.5;
      } else if (particlesRef.current) {
        (particlesRef.current.material as THREE.PointsMaterial).opacity = 0;
      }
      renderer.render(scene, camera);
    };
    animate();

    return () => {
      cancelAnimationFrame(animationId);
      if (containerRef.current && rendererRef.current?.domElement.parentElement === containerRef.current) {
        containerRef.current.removeChild(rendererRef.current.domElement);
      }
      geometry.dispose();
      material.dispose();
      particleGeo.dispose();
      particleMat.dispose();
      renderer.dispose();
    };
  }, []);

  const applyOptions = async (preset = selectedRegion, loop = loopEnabled) => {
    const data = await fbApp.invoke<any>("dharma.setSendOptions", {
      regionMode: preset.id,
      global: preset.global === true,
      countryCodes: preset.countryCodes || [],
      fieldEnergy: preset.fieldEnergy === true,
      localLoopback: preset.localLoopback === true,
      loop,
    });
    setStatus(data);
    return data;
  };

  const handleStart = async () => {
    if (!text.trim() && !selectedMaterial) {
      log("请先输入链接、正文，或选择高能素材");
      return;
    }
    setBusy(true);
    try {
      log("正在提取内容并启动全球法布施...");
      await applyOptions();
      const data = await fbApp.invoke<any>("dharma.startGlobalSend", {
        title: selectedMaterial?.title || "小程序全球法布施",
        text: text.trim(),
        global: selectedRegion.global === true,
        countryCodes: selectedRegion.countryCodes || [],
        fieldEnergy: selectedRegion.fieldEnergy === true,
        localLoopback: selectedRegion.localLoopback === true,
        loop: loopEnabled,
      });
      setStatus(data);
      setSelectedMaterial(data?.selectedContent);
      log("启动成功，正在发送。");
      if (selectedRegion.fieldEnergy && data?.wifiHotspot?.message) {
        log(data.wifiHotspot.message);
      }
    } catch (error) {
      log(hostErrorMessage(error, "启动失败"));
    } finally {
      setBusy(false);
    }
  };

  const handleStop = async () => {
    try {
      log("正在停止全球传输...");
      const data = await fbApp.invoke<any>("dharma.stopGlobalSend");
      setStatus(data);
      log("传输已停止。");
    } catch (error) {
      log(hostErrorMessage(error, "停止失败"));
    }
  };

  const handleRegionChange = async (preset: RegionPreset) => {
    setRegionId(preset.id);
    try {
      const data = await applyOptions(preset);
      setStatus(data);
      log(`地区模式已切换：${preset.label}`);
      if (preset.fieldEnergy && data?.wifiHotspot?.message) {
        log(data.wifiHotspot.message);
      }
    } catch (error) {
      log(hostErrorMessage(error, "地区模式切换失败"));
    }
  };

  const handleMaterial = async () => {
    setBusy(true);
    try {
      log("正在准备高能素材...");
      const unlocked = await ensureHighEnergyPurchase();
      if (!unlocked) return;
      const data = await fbApp.invoke<any>("dharma.selectHighEnergyMaterial");
      setStatus(data);
      setSelectedMaterial(data?.selectedContent);
      log("已选择高能素材。");
    } catch (error) {
      log(hostErrorMessage(error, "素材选择失败"));
    } finally {
      setBusy(false);
    }
  };

  const handleLoopChange = async (checked: boolean) => {
    setLoopEnabled(checked);
    try {
      const data = await applyOptions(selectedRegion, checked);
      setStatus(data);
    } catch (error) {
      log(hostErrorMessage(error, "循环模式设置失败"));
    }
  };

  const refreshStatus = async () => {
    try {
      setStatus(await fbApp.invoke<any>("dharma.getSendStatus"));
    } catch (error) {
      log(hostErrorMessage(error, "刷新状态失败"));
    }
  };

  return (
    <div className="ma-panel ma-global ma-fade-in" style={{ "--accent-start": "#4CAF7A", "--accent-end": "#2E7D32", "--accent-rgb": "76, 175, 122" } as any}>
      <div className="ma-title-row">
        <div>
          <h1 className="ma-header-title">全球法布施</h1>
          <p className="ma-header-subtitle">已发送 {status?.sentCount || 0} 个节点 · {(status?.sentMB || 0).toFixed(2)} MB</p>
        </div>
        <button className="ma-icon-btn" onClick={refreshStatus} aria-label="刷新状态">
          <RefreshCw size={18} />
        </button>
      </div>

      <div
        ref={containerRef}
        className="ma-earth"
      />

      <label className="ma-label">地区模式</label>
      <div className="ma-segment-grid">
        {regionPresets.map((preset) => (
          <button
            key={preset.id}
            className={`ma-chip-btn ${regionId === preset.id ? "active" : ""}`}
            onClick={() => handleRegionChange(preset)}
          >
            <Globe size={15} />
            {preset.label}
          </button>
        ))}
      </div>

      <div className="ma-toggle-row ma-compact-toggle">
        <div className="ma-toggle-info">
          <span className="ma-toggle-title">循环发送</span>
          <span className="ma-toggle-desc">{loopEnabled ? "持续循环" : "单轮发送"}</span>
        </div>
        <label className="ma-switch">
          <input type="checkbox" checked={loopEnabled} onChange={(event) => handleLoopChange(event.target.checked)} />
          <span className="ma-slider"></span>
        </label>
      </div>

      <label className="ma-label">高能素材</label>
      <button className={`ma-material-button ${selectedMaterial ? "selected" : ""}`} onClick={handleMaterial} disabled={busy}>
        <Sparkles size={18} />
        <span>{selectedMaterial?.title || `${HIGH_ENERGY_PRODUCT.title}${highEnergyUnlocked ? " · 已购买" : ` · ${HIGH_ENERGY_PRODUCT.priceLabel}`}`}</span>
      </button>

      <label className="ma-label">链接或正文</label>
      <textarea
        className="ma-textarea"
        placeholder="输入链接后发送，会自动提取正文。"
        value={text}
        onChange={(e) => setText(e.target.value)}
      />

      {selectedMaterial?.previewText && (
        <div className="ma-selected-content">
          <Link2 size={15} />
          <span>{selectedMaterial.previewText}</span>
        </div>
      )}

      <div className="ma-action-row">
        <button className="ma-btn" onClick={handleStart} disabled={busy || status?.isPreparingSend}>
          <Send size={19} />
          {busy || status?.isPreparingSend ? "准备中" : "发送"}
        </button>
        {status?.isTransferring && (
          <button className="ma-btn ma-btn-secondary" onClick={handleStop}>
            <CircleStop size={19} />
            停止
          </button>
        )}
      </div>

      {logs.length > 0 && (
        <div className="ma-log-box">
          {logs.map((l, i) => <div key={i}>{l}</div>)}
        </div>
      )}
    </div>
  );
}
