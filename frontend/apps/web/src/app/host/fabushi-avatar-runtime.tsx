import {
  forwardRef,
  useEffect,
  useId,
  useImperativeHandle,
  useMemo,
  useRef,
  type CSSProperties,
} from "react";

import type { BotMarkColor, BotMarkShape, BotMarkState } from "./bot-mark";

export type FabushiAvatarRuntimeHandle = {
  spin: (durationMs?: number) => void;
  bounce: () => void;
  burst: () => void;
};

export type FabushiAvatarRuntimeProps = {
  identity: string;
  state: BotMarkState;
  size: number;
  shape: BotMarkShape;
  color: BotMarkColor;
  gaze?: { x: number; y: number } | null;
  followPointer?: boolean;
  emphasis?: boolean;
  paused?: boolean;
  eyeColor?: string;
};

type MotionProfile = {
  amplitude: number;
  periodMs: number;
  tilt: number;
  eyeScale: number;
  blinkMs: number;
};

const VIEW_BOX = "-16 -16 260 260";
const C = 114;
const TAU = Math.PI * 2;

const COLORS: Record<BotMarkColor, { light: string; mid: string; dark: string }> = {
  black: { light: "#4f4f4f", mid: "#151515", dark: "#000000" },
  brown: { light: "#c49d79", mid: "#A27952", dark: "#6b4527" },
  red: { light: "#ff7d8a", mid: "#FF3E51", dark: "#c6162a" },
  orange: { light: "#ffad75", mid: "#FF781C", dark: "#c94f00" },
  yellow: { light: "#ffd083", mid: "#FFAF38", dark: "#d77c00" },
  green: { light: "#67e2ac", mid: "#00C972", dark: "#00844a" },
  cyan: { light: "#79e5d8", mid: "#1CC3B0", dark: "#008f80" },
  blue: { light: "#79b9ff", mid: "#2A92FE", dark: "#075eaf" },
  violet: { light: "#cab3ff", mid: "#A97EFE", dark: "#7040c8" },
  magenta: { light: "#ffabd5", mid: "#FF5EB1", dark: "#bd1d70" },
  gray: { light: "#c5c5c5", mid: "#959595", dark: "#5f5f5f" },
};

const DEFAULT_MOTION: MotionProfile = {
  amplitude: 1.5,
  periodMs: 7000,
  tilt: 0,
  eyeScale: 1,
  blinkMs: 4200,
};

const MOTION: Partial<Record<BotMarkState, MotionProfile>> = {
  sleeping: { amplitude: 0.2, periodMs: 8000, tilt: 0, eyeScale: 0.15, blinkMs: 8000 },
  waking: { amplitude: 2.5, periodMs: 900, tilt: 0, eyeScale: 0.55, blinkMs: 1800 },
  idle: DEFAULT_MOTION,
  listening: { amplitude: 1.8, periodMs: 2600, tilt: -2, eyeScale: 1, blinkMs: 3200 },
  thinking: { amplitude: 1.2, periodMs: 1900, tilt: 3, eyeScale: 0.78, blinkMs: 3000 },
  searching: { amplitude: 2.4, periodMs: 950, tilt: -4, eyeScale: 0.9, blinkMs: 2600 },
  working: { amplitude: 2.2, periodMs: 1600, tilt: -3, eyeScale: 1, blinkMs: 2600 },
  "tool-running": { amplitude: 2.8, periodMs: 1200, tilt: -5, eyeScale: 1, blinkMs: 2200 },
  speaking: { amplitude: 2.2, periodMs: 900, tilt: 1, eyeScale: 1.05, blinkMs: 2600 },
  result: { amplitude: 1.8, periodMs: 2800, tilt: 0, eyeScale: 1.1, blinkMs: 3400 },
  error: { amplitude: 1.2, periodMs: 700, tilt: -7, eyeScale: 0.7, blinkMs: 1800 },
  excited: { amplitude: 5, periodMs: 1000, tilt: 0, eyeScale: 1.08, blinkMs: 2200 },
  happy: { amplitude: 3, periodMs: 2400, tilt: 0, eyeScale: 1.06, blinkMs: 3200 },
  celebrate: { amplitude: 7, periodMs: 1300, tilt: 0, eyeScale: 1.12, blinkMs: 2200 },
  curious: { amplitude: 2, periodMs: 1800, tilt: 6, eyeScale: 1, blinkMs: 2800 },
  confused: { amplitude: 1.2, periodMs: 2200, tilt: -5, eyeScale: 0.82, blinkMs: 2600 },
  suspicious: { amplitude: 0.8, periodMs: 2600, tilt: 7, eyeScale: 0.72, blinkMs: 2400 },
  angry: { amplitude: 1, periodMs: 2000, tilt: -7, eyeScale: 0.62, blinkMs: 2400 },
  sad: { amplitude: 0.8, periodMs: 4200, tilt: -4, eyeScale: 0.58, blinkMs: 4200 },
  laughing: { amplitude: 4, periodMs: 1100, tilt: 0, eyeScale: 0.78, blinkMs: 1800 },
  scared: { amplitude: 3.5, periodMs: 800, tilt: 0, eyeScale: 1.12, blinkMs: 1500 },
  playful: { amplitude: 4, periodMs: 1450, tilt: 8, eyeScale: 1.04, blinkMs: 2400 },
  drowsy: { amplitude: 0.5, periodMs: 4200, tilt: 0, eyeScale: 0.28, blinkMs: 5200 },
  bored: { amplitude: 0.4, periodMs: 3600, tilt: -8, eyeScale: 0.45, blinkMs: 4800 },
  proud: { amplitude: 2, periodMs: 3300, tilt: 4, eyeScale: 1, blinkMs: 3600 },
  shy: { amplitude: 1, periodMs: 3200, tilt: -8, eyeScale: 0.55, blinkMs: 3600 },
  surprised: { amplitude: 3, periodMs: 2200, tilt: 0, eyeScale: 1.2, blinkMs: 2200 },
  orbit: { amplitude: 2.2, periodMs: 3600, tilt: 10, eyeScale: 1, blinkMs: 3000 },
  radar: { amplitude: 2.2, periodMs: 1500, tilt: -10, eyeScale: 0.9, blinkMs: 2600 },
  progress: { amplitude: 2, periodMs: 2100, tilt: 0, eyeScale: 1, blinkMs: 3000 },
  spawning: { amplitude: 4.5, periodMs: 1100, tilt: 0, eyeScale: 1, blinkMs: 2200 },
  humming: { amplitude: 1.5, periodMs: 4600, tilt: 0, eyeScale: 0.9, blinkMs: 3600 },
  loading: { amplitude: 2, periodMs: 1600, tilt: 3, eyeScale: 0.9, blinkMs: 2800 },
  dictating: { amplitude: 2.2, periodMs: 1200, tilt: 0, eyeScale: 1, blinkMs: 2800 },
  writing: { amplitude: 2.1, periodMs: 1500, tilt: -4, eyeScale: 1, blinkMs: 2600 },
  sending: { amplitude: 2.4, periodMs: 1300, tilt: 3, eyeScale: 1, blinkMs: 2600 },
  receiving: { amplitude: 2.4, periodMs: 1300, tilt: -3, eyeScale: 1, blinkMs: 2600 },
  uploading: { amplitude: 2.5, periodMs: 1200, tilt: 0, eyeScale: 1, blinkMs: 2500 },
  notifying: { amplitude: 3.2, periodMs: 1000, tilt: 0, eyeScale: 1.08, blinkMs: 2200 },
  alerting: { amplitude: 2.8, periodMs: 800, tilt: -6, eyeScale: 1.08, blinkMs: 1800 },
  dragging: { amplitude: 3, periodMs: 1400, tilt: 5, eyeScale: 1, blinkMs: 2600 },
  bouncing: { amplitude: 7, periodMs: 1000, tilt: 0, eyeScale: 1, blinkMs: 2200 },
  "powering-down": { amplitude: 0.2, periodMs: 8000, tilt: 0, eyeScale: 0.15, blinkMs: 8000 },
};

function roundedRectPath(width: number, height: number, radius: number): string {
  const left = C - width / 2;
  const top = C - height / 2;
  const right = C + width / 2;
  const bottom = C + height / 2;
  return `M${left + radius} ${top}H${right - radius}Q${right} ${top} ${right} ${top + radius}V${bottom - radius}Q${right} ${bottom} ${right - radius} ${bottom}H${left + radius}Q${left} ${bottom} ${left} ${bottom - radius}V${top + radius}Q${left} ${top} ${left + radius} ${top}Z`;
}

function polygonPath(sides: number, radius: number, rotation = -Math.PI / 2): string {
  return Array.from({ length: sides }, (_, index) => {
    const angle = rotation + index / sides * TAU;
    const x = C + Math.cos(angle) * radius;
    const y = C + Math.sin(angle) * radius;
    return `${index === 0 ? "M" : "L"}${x.toFixed(2)} ${y.toFixed(2)}`;
  }).join("") + "Z";
}

function personaPath(shape: BotMarkShape): string {
  switch (shape) {
    case "pebble":
      return "M31 105C31 55 64 21 116 20C170 19 204 54 201 111C198 166 168 202 112 203C60 204 31 166 31 105Z";
    case "squircle":
      return roundedRectPath(178, 178, 46);
    case "tablet":
      return roundedRectPath(190, 132, 66);
    case "wedge":
      return "M114 15C156 15 194 38 210 74L151 203C142 222 115 224 103 207L20 88C7 69 19 42 42 31C65 20 89 15 114 15Z";
    case "hex":
      return polygonPath(6, 102);
    case "cloud":
      return "M44 177C15 161 8 124 28 99C17 68 41 37 73 40C89 12 130 8 151 31C184 20 215 45 211 78C237 97 235 137 208 153C202 188 167 207 136 195C112 219 70 212 57 183C53 181 48 179 44 177Z";
    case "teardrop":
      return "M114 12C114 12 205 102 205 151C205 202 164 224 114 224C64 224 23 202 23 151C23 102 114 12 114 12Z";
    case "blob":
    default:
      return "M221 113C221 168 179 211 119 215C63 219 20 184 12 133C3 80 34 31 86 15C138 -1 194 22 214 70C220 84 222 99 221 113Z";
  }
}

function reducedMotion(): boolean {
  return typeof window !== "undefined" && window.matchMedia?.("(prefers-reduced-motion: reduce)").matches === true;
}

function hashIdentity(value: string): number {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) hash = Math.imul(hash ^ value.charCodeAt(index), 16777619);
  return hash >>> 0;
}

export const FabushiAvatarRuntime = forwardRef<FabushiAvatarRuntimeHandle, FabushiAvatarRuntimeProps>(
  function FabushiAvatarRuntime(
    {
      identity,
      state,
      size,
      shape,
      color,
      gaze = null,
      followPointer = false,
      emphasis = false,
      paused = false,
      eyeColor = "#ffffff",
    },
    ref,
  ) {
    const gradientId = useId().replace(/:/g, "");
    const faceRef = useRef<SVGGElement>(null);
    const eyesRef = useRef<SVGGElement>(null);
    const pointerGaze = useRef({ x: 0, y: 0 });
    const actionRef = useRef<{ kind: "spin" | "bounce" | "burst"; startedAt: number; durationMs: number } | null>(null);
    const motion = MOTION[state] ?? DEFAULT_MOTION;
    const palette = COLORS[color] ?? COLORS.gray;
    const phaseOffset = useMemo(() => (hashIdentity(identity) % 10000) / 10000 * TAU, [identity]);

    useImperativeHandle(ref, () => ({
      spin: (durationMs = 520) => { actionRef.current = { kind: "spin", startedAt: performance.now(), durationMs }; },
      bounce: () => { actionRef.current = { kind: "bounce", startedAt: performance.now(), durationMs: 520 }; },
      burst: () => { actionRef.current = { kind: "burst", startedAt: performance.now(), durationMs: 760 }; },
    }), []);

    useEffect(() => {
      if (!followPointer || typeof window === "undefined") return;
      const move = (event: PointerEvent) => {
        pointerGaze.current = {
          x: Math.max(-1, Math.min(1, (event.clientX / Math.max(1, window.innerWidth) - 0.5) * 2)),
          y: Math.max(-1, Math.min(1, (event.clientY / Math.max(1, window.innerHeight) - 0.5) * 2)),
        };
      };
      window.addEventListener("pointermove", move, { passive: true });
      return () => window.removeEventListener("pointermove", move);
    }, [followPointer]);

    useEffect(() => {
      const face = faceRef.current;
      const eyes = eyesRef.current;
      if (!face || !eyes) return;
      if (paused || reducedMotion()) {
        face.setAttribute("transform", `rotate(${motion.tilt * 0.25} ${C} ${C})`);
        eyes.setAttribute("transform", `scale(1 ${motion.eyeScale})`);
        return;
      }

      let frame = 0;
      const startedAt = performance.now();
      const tick = (now: number) => {
        const elapsed = now - startedAt;
        const phase = elapsed / motion.periodMs * TAU + phaseOffset;
        const bob = Math.sin(phase) * motion.amplitude * (emphasis ? 1.25 : 1);
        const action = actionRef.current;
        let spin = 0;
        let bounce = 0;
        if (action) {
          const p = Math.min(1, Math.max(0, (now - action.startedAt) / action.durationMs));
          const envelope = Math.sin(p * Math.PI);
          if (action.kind === "spin" || action.kind === "burst") spin = p * 360;
          if (action.kind === "bounce" || action.kind === "burst") bounce = envelope * 10;
          if (p >= 1) actionRef.current = null;
        }
        const target = gaze ?? pointerGaze.current;
        const gx = Math.max(-1, Math.min(1, target?.x ?? 0));
        const gy = Math.max(-1, Math.min(1, target?.y ?? 0));
        const blinkWave = Math.sin(elapsed / Math.max(1000, motion.blinkMs) * TAU);
        const blinkScale = blinkWave > 0.985 ? 0.18 : motion.eyeScale;
        face.setAttribute("transform", `translate(0 ${(-bob - bounce).toFixed(2)}) rotate(${(motion.tilt + spin).toFixed(2)} ${C} ${C})`);
        eyes.setAttribute("transform", `translate(${(gx * 4).toFixed(2)} ${(gy * 3).toFixed(2)}) scale(1 ${blinkScale.toFixed(3)})`);
        frame = requestAnimationFrame(tick);
      };
      frame = requestAnimationFrame(tick);
      return () => cancelAnimationFrame(frame);
    }, [emphasis, gaze, motion, paused, phaseOffset]);

    const rootStyle: CSSProperties = {
      display: "block",
      width: size,
      height: size,
      overflow: "visible",
      userSelect: "none",
      WebkitUserSelect: "none",
    };
    const happy = state === "happy" || state === "excited" || state === "celebrate" || state === "result" || state === "laughing";

    return (
      <svg
        aria-hidden="true"
        data-fabushi-avatar-runtime="v1"
        data-state={state}
        data-shape={shape}
        height={size}
        width={size}
        style={rootStyle}
        viewBox={VIEW_BOX}
        xmlns="http://www.w3.org/2000/svg"
      >
        <defs>
          <linearGradient id={`${gradientId}-body`} x1="0" x2="1" y1="0" y2="1">
            <stop offset="0" stopColor={palette.light} />
            <stop offset="0.52" stopColor={palette.mid} />
            <stop offset="1" stopColor={palette.dark} />
          </linearGradient>
          <radialGradient id={`${gradientId}-shine`} cx="35%" cy="25%" r="65%">
            <stop offset="0" stopColor="#ffffff" stopOpacity="0.28" />
            <stop offset="1" stopColor="#ffffff" stopOpacity="0" />
          </radialGradient>
        </defs>
        <g ref={faceRef}>
          <path d={personaPath(shape)} fill={`url(#${gradientId}-body)`} />
          <path d={personaPath(shape)} fill={`url(#${gradientId}-shine)`} opacity="0.9" />
          <g ref={eyesRef} fill={eyeColor} transformOrigin={`${C}px ${C}px`}>
            <ellipse cx={C - 29} cy={C - 8} rx="10" ry="7" />
            <ellipse cx={C + 29} cy={C - 8} rx="10" ry="7" />
          </g>
          {happy ? (
            <path
              d={`M${C - 20} ${C + 24} Q${C} ${C + 38} ${C + 20} ${C + 24}`}
              fill="none"
              stroke={eyeColor}
              strokeLinecap="round"
              strokeWidth="5"
            />
          ) : null}
        </g>
      </svg>
    );
  },
);
