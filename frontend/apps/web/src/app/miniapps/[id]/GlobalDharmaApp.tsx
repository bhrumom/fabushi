"use client";

import React, { useState, useEffect, useRef } from "react";
import * as THREE from "three";
import "./miniapps.css";

export default function GlobalDharmaApp() {
  const [text, setText] = useState("");
  const [status, setStatus] = useState<any>(null);
  const [loopbackEnabled, setLoopbackEnabled] = useState(false);
  const [logs, setLogs] = useState<string[]>([]);
  const containerRef = useRef<HTMLDivElement>(null);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  const sceneRef = useRef<THREE.Scene | null>(null);
  const earthRef = useRef<THREE.Mesh | null>(null);
  const particlesRef = useRef<THREE.Points | null>(null);

  const log = (msg: string) => setLogs((prev) => [...prev, `[${new Date().toLocaleTimeString()}] ${msg}`]);

  useEffect(() => {
    // Check initial status
    if (window.FabushiMiniApp?.ready) {
      window.FabushiMiniApp.invoke("dharma.getSendStatus").then((res: any) => {
        setStatus(res);
      });
    }

    // Init Three.js 3D Earth
    if (!containerRef.current) return;
    
    const width = containerRef.current.clientWidth;
    const height = 300;
    const scene = new THREE.Scene();
    sceneRef.current = scene;

    const camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 1000);
    camera.position.z = 2.5;

    const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true });
    renderer.setSize(width, height);
    renderer.setPixelRatio(window.devicePixelRatio);
    containerRef.current.appendChild(renderer.domElement);
    rendererRef.current = renderer;

    // Earth Sphere
    const geometry = new THREE.SphereGeometry(1, 64, 64);
    
    // Wireframe earth material for tech feel
    const material = new THREE.MeshBasicMaterial({ 
      color: 0x4CAF7A, 
      wireframe: true,
      transparent: true,
      opacity: 0.3
    });
    
    const earth = new THREE.Mesh(geometry, material);
    scene.add(earth);
    earthRef.current = earth;

    // Particles (invisible at first, will burst when transferring)
    const particleGeo = new THREE.BufferGeometry();
    const particleCount = 1000;
    const posArray = new Float32Array(particleCount * 3);
    for(let i=0; i < particleCount * 3; i++) {
      posArray[i] = (Math.random() - 0.5) * 2;
    }
    particleGeo.setAttribute('position', new THREE.BufferAttribute(posArray, 3));
    const particleMat = new THREE.PointsMaterial({
      size: 0.02,
      color: 0x88FFB4,
      transparent: true,
      opacity: 0
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
      if (particlesRef.current && status?.isTransferring) {
        particlesRef.current.rotation.y -= 0.01;
        // Make particles visible and pulse
        (particlesRef.current.material as THREE.PointsMaterial).opacity = 0.5 + Math.sin(Date.now() * 0.005) * 0.5;
      } else if (particlesRef.current) {
        (particlesRef.current.material as THREE.PointsMaterial).opacity = 0;
      }
      renderer.render(scene, camera);
    };
    animate();

    return () => {
      cancelAnimationFrame(animationId);
      if (containerRef.current && rendererRef.current) {
        containerRef.current.removeChild(rendererRef.current.domElement);
      }
    };
  }, [status?.isTransferring]);

  const handleStart = async () => {
    if (!window.FabushiMiniApp) {
      log("SDK 尚未就绪");
      return;
    }
    log("正在启动全球法布施传输...");
    const res = await window.FabushiMiniApp.invoke("dharma.startGlobalSend", {
      title: "小程序全球法布施",
      text: text || "愿以此功德，普及于一切。",
    });
    setStatus(res.data);
    log(res.ok ? "启动成功，正在全网节点传输中。" : `启动失败: ${res.message}`);
  };

  const handleStop = async () => {
    if (!window.FabushiMiniApp) return;
    log("正在停止全球传输...");
    const res = await window.FabushiMiniApp.invoke("dharma.stopGlobalSend");
    setStatus(res.data);
    log("传输已停止。");
  };

  const handleTestLoopback = async () => {
    if (!window.FabushiMiniApp) return;
    log("测试本地回环 (127.0.0.1)...");
    const res = await window.FabushiMiniApp.invoke("localLoopback.fetch", {
      url: "http://127.0.0.1:8080/health",
      method: "GET"
    });
    if (res.ok) {
      log(`回环响应成功: ${res.data.statusCode}`);
    } else {
      log(`回环请求失败: ${res.message}`);
    }
  };

  return (
    <div className="ma-card ma-fade-in" style={{ "--accent-start": "#4CAF7A", "--accent-end": "#2E7D32", "--accent-rgb": "76, 175, 122" } as any}>
      <h1 className="ma-header-title">全球法布施节点</h1>
      <p className="ma-header-subtitle">配置您的节点传输策略，通过本地引擎向全球进行法布施。</p>

      {/* 3D Earth Container */}
      <div 
        ref={containerRef} 
        style={{ 
          width: "100%", 
          height: 300, 
          margin: "24px 0", 
          background: "radial-gradient(circle, rgba(76, 175, 122, 0.1) 0%, transparent 70%)",
          borderRadius: 16
        }} 
      />

      <label className="ma-label">传播内容</label>
      <textarea
        className="ma-textarea"
        placeholder="输入法布施的正文或文章链接..."
        value={text}
        onChange={(e) => setText(e.target.value)}
      />

      <div className="ma-toggle-row">
        <div className="ma-toggle-info">
          <span className="ma-toggle-title">开启本地回环探测</span>
          <span className="ma-toggle-desc">允许小程序探测本机并绕过沙箱环境</span>
        </div>
        <label className="ma-switch">
          <input type="checkbox" checked={loopbackEnabled} onChange={(e) => setLoopbackEnabled(e.target.checked)} />
          <span className="ma-slider"></span>
        </label>
      </div>

      <div style={{ display: "flex", gap: 12, marginTop: 24, marginBottom: 12 }}>
        <button className="ma-btn" onClick={handleStart}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><polygon points="5 3 19 12 5 21 5 3"></polygon></svg>
          启动全球传输
        </button>
        {status?.isTransferring && (
          <button className="ma-btn ma-btn-secondary" onClick={handleStop} style={{ flex: 0.5 }}>
            停止
          </button>
        )}
      </div>

      {loopbackEnabled && (
        <button className="ma-btn ma-btn-secondary" onClick={handleTestLoopback} style={{ marginBottom: 16 }}>
          测试本地 Loopback API
        </button>
      )}

      {logs.length > 0 && (
        <div className="ma-log-box">
          {logs.map((l, i) => <div key={i}>{l}</div>)}
        </div>
      )}
    </div>
  );
}
