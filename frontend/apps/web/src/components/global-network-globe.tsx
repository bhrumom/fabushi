"use client";

import { useEffect, useRef, useState } from "react";
import { siteHref } from "../lib/site-url";

interface NetworkNode {
  id: string;
  country: string;
  city: string;
  continent: string;
  lat: number;
  lng: number;
  tier: number;
}

interface NetworkRoutePayload {
  from: string;
  to: string;
}

interface GlobePayload {
  nodes: NetworkNode[];
  routes: NetworkRoutePayload[];
}

interface NetworkRoute {
  from: NetworkNode;
  to: NetworkNode;
}

interface ProjectedPoint {
  x: number;
  y: number;
  visibility: number;
}

interface TooltipState {
  left: number;
  top: number;
  node: NetworkNode;
}

interface GlobeRuntime {
  image: HTMLImageElement;
  nodes: NetworkNode[];
  routes: NetworkRoute[];
  rotation: number;
  time: number;
}

function normalizeLongitude(value: number) {
  return ((((value + 540) % 360) + 360) % 360) - 180;
}

function project(
  lat: number,
  lng: number,
  rotation: number,
  centerX: number,
  centerY: number,
  radius: number,
): ProjectedPoint | null {
  const relativeLng = (normalizeLongitude(lng - rotation) * Math.PI) / 180;
  const latRad = (lat * Math.PI) / 180;
  const visibility = Math.cos(latRad) * Math.cos(relativeLng);
  if (visibility < -0.14) return null;

  return {
    x: centerX + radius * Math.cos(latRad) * Math.sin(relativeLng),
    y: centerY - radius * Math.sin(latRad),
    visibility,
  };
}

function getMetrics(width: number, height: number) {
  const radius = Math.min(width * 0.72, height * 0.92);
  return {
    centerX: width * 0.52,
    centerY: height * 0.88,
    radius: Math.max(148, Math.min(radius, 720)),
  };
}

function quadraticPoint(
  start: ProjectedPoint,
  control: { x: number; y: number },
  end: ProjectedPoint,
  t: number,
) {
  const inverse = 1 - t;
  return {
    x: inverse * inverse * start.x + 2 * inverse * t * control.x + t * t * end.x,
    y: inverse * inverse * start.y + 2 * inverse * t * control.y + t * t * end.y,
  };
}

function loadImage(src: string) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const image = new Image();
    image.decoding = "async";
    image.onload = () => resolve(image);
    image.onerror = reject;
    image.src = src;
  });
}

export function GlobalNetworkGlobe() {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const runtimeRef = useRef<GlobeRuntime | null>(null);
  const hoveredRef = useRef<NetworkNode | null>(null);
  const reduceMotionRef = useRef(false);
  const [tooltip, setTooltip] = useState<TooltipState | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const drawingCanvas = canvas;
    const resolvedContext = drawingCanvas.getContext("2d");
    if (!resolvedContext) return;
    const context = resolvedContext;

    let raf = 0;
    let disposed = false;
    let lastFrame = 0;
    const ratio = Math.min(window.devicePixelRatio || 1, 2);
    reduceMotionRef.current = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    function resize() {
      const rect = drawingCanvas.getBoundingClientRect();
      drawingCanvas.width = Math.max(1, Math.floor(rect.width * ratio));
      drawingCanvas.height = Math.max(1, Math.floor(rect.height * ratio));
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
      draw(0);
    }

    function drawProjectedTexture(
      image: HTMLImageElement,
      centerX: number,
      centerY: number,
      radius: number,
      rotation: number,
    ) {
      const columns = Math.round(Math.min(192, Math.max(74, radius / 2.2)));
      const rows = Math.round(Math.min(128, Math.max(48, radius / 3)));
      const cellWidth = (radius * 2) / columns;
      const cellHeight = (radius * 2) / rows;

      context.imageSmoothingEnabled = true;
      context.imageSmoothingQuality = "high";

      for (let col = 0; col < columns; col += 1) {
        const x0 = -radius + col * cellWidth;
        const x1 = x0 + cellWidth + 0.8;
        const nx0 = Math.max(-1, Math.min(1, x0 / radius));
        const nx1 = Math.max(-1, Math.min(1, x1 / radius));
        const midX = Math.max(-1, Math.min(1, (x0 + x1) / (2 * radius)));
        const z = Math.sqrt(Math.max(0, 1 - midX * midX));
        const lon = normalizeLongitude(rotation + (Math.atan2(midX, z) * 180) / Math.PI);
        const sourceX = ((lon + 180) / 360) * image.width;
        const sourceWidth = Math.max(
          1,
          (Math.abs(Math.asin(nx1) - Math.asin(nx0)) * 180 * image.width * 1.22) / (Math.PI * 360),
        );

        for (let row = 0; row < rows; row += 1) {
          const y0 = -radius + row * cellHeight;
          const y1 = y0 + cellHeight + 0.8;
          const midY = Math.max(-1, Math.min(1, (y0 + y1) / (2 * radius)));
          if (midX * midX + midY * midY > 1.025) continue;

          const lat = (Math.asin(Math.max(-1, Math.min(1, -midY))) * 180) / Math.PI;
          const sourceY = ((90 - lat) / 180) * image.height;
          const sourceHeight = Math.max(1, (cellHeight / (radius * 2)) * image.height * 1.12);
          const sx = sourceX - sourceWidth / 2;
          const sy = Math.max(0, Math.min(image.height - 1, sourceY - sourceHeight / 2));
          const sh = Math.max(1, Math.min(sourceHeight, image.height - sy));
          let wrappedX = sx % image.width;
          if (wrappedX < 0) wrappedX += image.width;

          const dx = centerX + x0;
          const dy = centerY + y0;
          const dw = x1 - x0;
          const dh = y1 - y0;

          if (wrappedX + sourceWidth <= image.width) {
            context.drawImage(image, wrappedX, sy, sourceWidth, sh, dx, dy, dw, dh);
          } else {
            const firstWidth = image.width - wrappedX;
            const firstRatio = firstWidth / sourceWidth;
            context.drawImage(image, wrappedX, sy, firstWidth, sh, dx, dy, dw * firstRatio, dh);
            context.drawImage(
              image,
              0,
              sy,
              sourceWidth - firstWidth,
              sh,
              dx + dw * firstRatio,
              dy,
              dw * (1 - firstRatio),
              dh,
            );
          }
        }
      }
    }

    function drawRoute(
      start: ProjectedPoint,
      end: ProjectedPoint,
      radius: number,
      progress: number,
      subtle: boolean,
    ) {
      const control = {
        x: (start.x + end.x) / 2,
        y: Math.min(start.y, end.y) - radius * (subtle ? 0.14 : 0.22),
      };

      context.beginPath();
      context.moveTo(start.x, start.y);
      context.quadraticCurveTo(control.x, control.y, end.x, end.y);
      context.strokeStyle = subtle ? "rgba(246, 139, 54, 0.18)" : "rgba(246, 139, 54, 0.28)";
      context.lineWidth = subtle ? 0.8 : 1.2;
      context.lineCap = "round";
      context.stroke();

      const head = quadraticPoint(start, control, end, progress);
      const tail = quadraticPoint(start, control, end, Math.max(0, progress - (subtle ? 0.12 : 0.18)));
      const gradient = context.createLinearGradient(tail.x, tail.y, head.x, head.y);
      gradient.addColorStop(0, "rgba(246, 139, 54, 0)");
      gradient.addColorStop(0.72, subtle ? "rgba(246, 139, 54, 0.48)" : "rgba(246, 139, 54, 0.82)");
      gradient.addColorStop(1, subtle ? "rgba(255, 227, 163, 0.72)" : "rgba(120, 214, 232, 0.92)");
      context.strokeStyle = gradient;
      context.lineWidth = subtle ? 1.6 : 3;
      context.beginPath();
      context.moveTo(tail.x, tail.y);
      context.lineTo(head.x, head.y);
      context.stroke();
    }

    function draw(timestamp: number) {
      const runtime = runtimeRef.current;
      const width = drawingCanvas.clientWidth;
      const height = drawingCanvas.clientHeight;
      const { centerX, centerY, radius } = getMetrics(width, height);

      context.clearRect(0, 0, width, height);
      const bg = context.createLinearGradient(width / 2, 0, width / 2, height);
      bg.addColorStop(0, "#05070d");
      bg.addColorStop(0.58, "#0c111a");
      bg.addColorStop(1, "#05070d");
      context.fillStyle = bg;
      context.fillRect(0, 0, width, height);

      const halo = context.createRadialGradient(centerX, centerY - radius * 0.08, radius * 0.12, centerX, centerY, radius * 1.15);
      halo.addColorStop(0, "rgba(232, 189, 107, 0.3)");
      halo.addColorStop(0.42, "rgba(120, 214, 232, 0.1)");
      halo.addColorStop(1, "rgba(232, 189, 107, 0)");
      context.fillStyle = halo;
      context.beginPath();
      context.arc(centerX, centerY, radius * 1.15, 0, Math.PI * 2);
      context.fill();

      context.save();
      context.beginPath();
      context.arc(centerX, centerY, radius, 0, Math.PI * 2);
      context.clip();

      const ocean = context.createRadialGradient(centerX - radius * 0.18, centerY - radius * 0.42, radius * 0.04, centerX, centerY, radius * 1.16);
      ocean.addColorStop(0, "#213344");
      ocean.addColorStop(0.42, "#132333");
      ocean.addColorStop(0.78, "#0b121d");
      ocean.addColorStop(1, "#05070d");
      context.fillStyle = ocean;
      context.beginPath();
      context.arc(centerX, centerY, radius, 0, Math.PI * 2);
      context.fill();

      if (runtime) {
        context.save();
        context.globalAlpha = 0.66;
        context.filter = "sepia(1) saturate(1.45) hue-rotate(342deg) brightness(0.82)";
        drawProjectedTexture(runtime.image, centerX, centerY, radius, runtime.rotation);
        context.restore();
      }

      const shine = context.createRadialGradient(centerX - radius * 0.22, centerY - radius * 0.36, radius * 0.08, centerX, centerY, radius * 1.18);
      shine.addColorStop(0, "rgba(255,227,163,0.2)");
      shine.addColorStop(0.58, "rgba(120,214,232,0.03)");
      shine.addColorStop(1, "rgba(5,7,13,0.26)");
      context.fillStyle = shine;
      context.fillRect(centerX - radius, centerY - radius, radius * 2, radius * 2);
      context.restore();

      context.strokeStyle = "rgba(232, 189, 107, 0.5)";
      context.lineWidth = 1.4;
      context.beginPath();
      context.arc(centerX, centerY, radius * 1.01, 0, Math.PI * 2);
      context.stroke();

      if (runtime) {
        runtime.routes.slice(0, 16).forEach((route, index) => {
          const start = project(route.from.lat, route.from.lng, runtime.rotation, centerX, centerY, radius);
          const end = project(route.to.lat, route.to.lng, runtime.rotation, centerX, centerY, radius);
          if (!start || !end || start.visibility < -0.02 || end.visibility < -0.02) return;
          drawRoute(start, end, radius, (runtime.time * 0.13 + index * 0.087) % 1, true);
        });

        runtime.nodes.forEach((node) => {
          const projected = project(node.lat, node.lng, runtime.rotation, centerX, centerY, radius);
          if (!projected || projected.visibility < -0.02) return;
          const active = hoveredRef.current?.id === node.id;
          const alpha = Math.max(0, Math.min(1, 0.38 + projected.visibility * 0.62));
          const nodeRadius = 1.25 + node.tier * 0.72 + (active ? 2 : 0);

          context.fillStyle = `rgba(232,189,107,${alpha * 0.32})`;
          context.beginPath();
          context.arc(projected.x, projected.y, nodeRadius + 3.2, 0, Math.PI * 2);
          context.fill();
          context.fillStyle = active ? `rgba(120,214,232,${alpha})` : `rgba(255,227,163,${alpha * 0.88})`;
          context.beginPath();
          context.arc(projected.x, projected.y, nodeRadius, 0, Math.PI * 2);
          context.fill();
          context.strokeStyle = `rgba(255,249,235,${alpha * 0.58})`;
          context.lineWidth = 0.75;
          context.stroke();
        });
      }

      const fade = context.createLinearGradient(0, height * 0.62, 0, height);
      fade.addColorStop(0, "rgba(5,7,13,0)");
      fade.addColorStop(0.62, "rgba(5,7,13,0.7)");
      fade.addColorStop(1, "rgba(5,7,13,0.98)");
      context.fillStyle = fade;
      context.fillRect(0, height * 0.62, width, height * 0.38);

      if (runtime && !hoveredRef.current && !reduceMotionRef.current) {
        const delta = lastFrame ? Math.min(0.05, (timestamp - lastFrame) / 1000) : 0;
        runtime.time += delta;
        runtime.rotation = normalizeLongitude(runtime.rotation + delta * 4.5);
      }
      lastFrame = timestamp;

      if (!disposed) {
        raf = window.requestAnimationFrame(draw);
      }
    }

    function findNode(localX: number, localY: number) {
      const runtime = runtimeRef.current;
      if (!runtime) return null;
      const width = drawingCanvas.clientWidth;
      const height = drawingCanvas.clientHeight;
      const { centerX, centerY, radius } = getMetrics(width, height);
      let closest: NetworkNode | null = null;
      let closestDistance = Infinity;

      runtime.nodes.forEach((node) => {
        const projected = project(node.lat, node.lng, runtime.rotation, centerX, centerY, radius);
        if (!projected || projected.visibility < 0) return;
        const distance = Math.hypot(projected.x - localX, projected.y - localY);
        const threshold = 8 + node.tier * 2.4;
        if (distance <= threshold && distance < closestDistance) {
          closest = node;
          closestDistance = distance;
        }
      });

      return closest;
    }

    function updateTooltip(node: NetworkNode | null) {
      hoveredRef.current = node;
      if (!node) {
        setTooltip(null);
        return;
      }
      const runtime = runtimeRef.current;
      if (!runtime) return;
      const width = drawingCanvas.clientWidth;
      const height = drawingCanvas.clientHeight;
      const { centerX, centerY, radius } = getMetrics(width, height);
      const projected = project(node.lat, node.lng, runtime.rotation, centerX, centerY, radius);
      if (!projected) return;
      setTooltip({ left: projected.x, top: projected.y, node });
    }

    function onPointerMove(event: PointerEvent) {
      const rect = drawingCanvas.getBoundingClientRect();
      const node = findNode(event.clientX - rect.left, event.clientY - rect.top);
      updateTooltip(node);
    }

    function onPointerDown(event: PointerEvent) {
      const rect = drawingCanvas.getBoundingClientRect();
      const node = findNode(event.clientX - rect.left, event.clientY - rect.top);
      updateTooltip(node);
    }

    function onPointerLeave() {
      updateTooltip(null);
    }

    Promise.all([
      fetch(siteHref("/global-network-globe.json")).then((response) => response.json() as Promise<GlobePayload>),
      loadImage(siteHref("/global-land-mask.png")),
    ])
      .then(([payload, image]) => {
        if (disposed) return;
        const nodeById = new Map(payload.nodes.map((node) => [node.id, node]));
        runtimeRef.current = {
          image,
          nodes: payload.nodes,
          routes: payload.routes
            .map((route) => {
              const from = nodeById.get(route.from);
              const to = nodeById.get(route.to);
              return from && to ? { from, to } : null;
            })
            .filter((route): route is NetworkRoute => route !== null),
          rotation: -101,
          time: 0,
        };
        resize();
      })
      .catch(() => {
        resize();
      });

    drawingCanvas.addEventListener("pointermove", onPointerMove);
    drawingCanvas.addEventListener("pointerdown", onPointerDown);
    drawingCanvas.addEventListener("pointerleave", onPointerLeave);
    window.addEventListener("resize", resize);
    resize();
    raf = window.requestAnimationFrame(draw);

    return () => {
      disposed = true;
      window.cancelAnimationFrame(raf);
      drawingCanvas.removeEventListener("pointermove", onPointerMove);
      drawingCanvas.removeEventListener("pointerdown", onPointerDown);
      drawingCanvas.removeEventListener("pointerleave", onPointerLeave);
      window.removeEventListener("resize", resize);
    };
  }, []);

  return (
    <div className="global-network-globe" aria-hidden="true">
      <canvas ref={canvasRef} />
      {tooltip ? (
        <div
          className="global-network-tooltip"
          style={{ left: tooltip.left, top: tooltip.top }}
        >
          <strong>{tooltip.node.city || tooltip.node.country}</strong>
          <span>
            {tooltip.node.city ? `${tooltip.node.country} · ${tooltip.node.continent}` : `${tooltip.node.continent} · 全球节点`}
          </span>
          <em>节点在线</em>
        </div>
      ) : null}
    </div>
  );
}
