"use client";

import { useEffect, useRef } from "react";

export function ZenOrbit() {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const canvasElement = canvas;

    const context = canvasElement.getContext("2d");
    if (!context) return;
    const drawingContext = context;

    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    let frame = 0;
    let raf = 0;

    function resize() {
      const rect = canvasElement.getBoundingClientRect();
      const ratio = Math.min(window.devicePixelRatio || 1, 2);
      canvasElement.width = Math.max(1, Math.floor(rect.width * ratio));
      canvasElement.height = Math.max(1, Math.floor(rect.height * ratio));
      drawingContext.setTransform(ratio, 0, 0, ratio, 0, 0);
    }

    function draw() {
      const width = canvasElement.clientWidth;
      const height = canvasElement.clientHeight;
      const centerX = width * 0.5;
      const centerY = height * 0.5;
      const radius = Math.min(width, height) * 0.28;
      const t = frame * 0.012;

      drawingContext.clearRect(0, 0, width, height);

      const glow = drawingContext.createRadialGradient(centerX, centerY, radius * 0.15, centerX, centerY, radius * 1.7);
      glow.addColorStop(0, "rgba(227, 191, 109, 0.32)");
      glow.addColorStop(0.45, "rgba(101, 197, 255, 0.16)");
      glow.addColorStop(1, "rgba(2, 4, 10, 0)");
      drawingContext.fillStyle = glow;
      drawingContext.beginPath();
      drawingContext.arc(centerX, centerY, radius * 1.7, 0, Math.PI * 2);
      drawingContext.fill();

      const sphere = drawingContext.createRadialGradient(
        centerX - radius * 0.35,
        centerY - radius * 0.4,
        radius * 0.05,
        centerX,
        centerY,
        radius,
      );
      sphere.addColorStop(0, "rgba(255, 246, 221, 0.96)");
      sphere.addColorStop(0.28, "rgba(103, 197, 255, 0.42)");
      sphere.addColorStop(0.74, "rgba(18, 31, 69, 0.76)");
      sphere.addColorStop(1, "rgba(4, 7, 16, 0.94)");
      drawingContext.fillStyle = sphere;
      drawingContext.beginPath();
      drawingContext.arc(centerX, centerY, radius, 0, Math.PI * 2);
      drawingContext.fill();

      drawingContext.save();
      drawingContext.beginPath();
      drawingContext.arc(centerX, centerY, radius, 0, Math.PI * 2);
      drawingContext.clip();

      drawingContext.strokeStyle = "rgba(221, 238, 255, 0.16)";
      drawingContext.lineWidth = 1;
      for (let i = -3; i <= 3; i += 1) {
        drawingContext.beginPath();
        drawingContext.ellipse(centerX, centerY, radius * (0.26 + Math.abs(i) * 0.11), radius, 0, 0, Math.PI * 2);
        drawingContext.stroke();
      }

      for (let i = -2; i <= 2; i += 1) {
        const y = centerY + i * radius * 0.22;
        const xShift = Math.sin(t + i) * radius * 0.05;
        drawingContext.beginPath();
        drawingContext.ellipse(centerX + xShift, y, radius * 0.96, radius * (0.16 + Math.abs(i) * 0.02), 0, 0, Math.PI * 2);
        drawingContext.stroke();
      }

      drawingContext.restore();

      for (let i = 0; i < 4; i += 1) {
        const phase = t + i * 1.38;
        const orbitRadius = radius * (1.08 + i * 0.12);
        const tilt = 0.34 + i * 0.08;
        drawingContext.strokeStyle = i % 2 === 0 ? "rgba(229, 185, 91, 0.42)" : "rgba(92, 204, 255, 0.34)";
        drawingContext.lineWidth = 1.2;
        drawingContext.beginPath();
        drawingContext.ellipse(centerX, centerY, orbitRadius, orbitRadius * tilt, phase, 0, Math.PI * 2);
        drawingContext.stroke();

        const dotX = centerX + Math.cos(phase * 1.7) * orbitRadius;
        const dotY = centerY + Math.sin(phase * 1.7) * orbitRadius * tilt;
        drawingContext.fillStyle = i % 2 === 0 ? "rgba(255, 214, 135, 0.9)" : "rgba(155, 226, 255, 0.9)";
        drawingContext.beginPath();
        drawingContext.arc(dotX, dotY, 2.6, 0, Math.PI * 2);
        drawingContext.fill();
      }

      for (let i = 0; i < 36; i += 1) {
        const angle = i * 2.399 + t * 0.35;
        const distance = radius * (1.35 + (i % 7) * 0.11);
        const x = centerX + Math.cos(angle) * distance;
        const y = centerY + Math.sin(angle * 0.82) * distance * 0.54;
        const alpha = 0.16 + ((i * 17) % 100) / 520;
        drawingContext.fillStyle = `rgba(244, 232, 192, ${alpha})`;
        drawingContext.beginPath();
        drawingContext.arc(x, y, 1.1 + (i % 3) * 0.55, 0, Math.PI * 2);
        drawingContext.fill();
      }

      if (!reduceMotion) {
        frame += 1;
        raf = window.requestAnimationFrame(draw);
      }
    }

    resize();
    draw();
    window.addEventListener("resize", resize);

    return () => {
      window.cancelAnimationFrame(raf);
      window.removeEventListener("resize", resize);
    };
  }, []);

  return (
    <div className="zen-orbit" aria-hidden="true">
      <canvas ref={canvasRef} />
    </div>
  );
}
