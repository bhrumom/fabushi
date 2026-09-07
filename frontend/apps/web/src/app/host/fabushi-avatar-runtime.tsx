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

const VIEW_BOX = "0 0 100 100";
const TAU = Math.PI * 2;
const IOS_GHOST_COLORS = ["#00C273", "#147DFA", "#874DFF", "#FF4F1A", "#F01F47", "#FA9E0A"] as const;

const DEFAULT_MOTION: MotionProfile = {
  amplitude: 1.2,
  periodMs: 4800,
  tilt: 0,
  eyeScale: 1,
  blinkMs: 4200,
};

const MOTION: Partial<Record<BotMarkState, MotionProfile>> = {
  sleeping: { amplitude: 0.2, periodMs: 8000, tilt: 0, eyeScale: 0.18, blinkMs: 8000 },
  waking: { amplitude: 2.1, periodMs: 1100, tilt: 0, eyeScale: 0.7, blinkMs: 1800 },
  idle: DEFAULT_MOTION,
  listening: { amplitude: 1.5, periodMs: 2600, tilt: -2, eyeScale: 1, blinkMs: 3200 },
  thinking: { amplitude: 1.1, periodMs: 1900, tilt: 3, eyeScale: 0.78, blinkMs: 3000 },
  searching: { amplitude: 2.0, periodMs: 1100, tilt: -4, eyeScale: 0.9, blinkMs: 2600 },
  working: { amplitude: 1.9, periodMs: 1700, tilt: -3, eyeScale: 1, blinkMs: 2600 },
  "tool-running": { amplitude: 2.3, periodMs: 1300, tilt: -5, eyeScale: 1, blinkMs: 2200 },
  speaking: { amplitude: 2.0, periodMs: 1000, tilt: 1, eyeScale: 1.05, blinkMs: 2600 },
  result: { amplitude: 1.6, periodMs: 2800, tilt: 0, eyeScale: 1.05, blinkMs: 3400 },
  error: { amplitude: 1.1, periodMs: 800, tilt: -7, eyeScale: 0.7, blinkMs: 1800 },
  excited: { amplitude: 3.6, periodMs: 1100, tilt: 0, eyeScale: 1.08, blinkMs: 2200 },
  happy: { amplitude: 2.5, periodMs: 2400, tilt: 0, eyeScale: 1.06, blinkMs: 3200 },
  celebrate: { amplitude: 4.2, periodMs: 1300, tilt: 0, eyeScale: 1.12, blinkMs: 2200 },
  curious: { amplitude: 1.8, periodMs: 1800, tilt: 6, eyeScale: 1, blinkMs: 2800 },
  confused: { amplitude: 1.1, periodMs: 2200, tilt: -5, eyeScale: 0.82, blinkMs: 2600 },
  suspicious: { amplitude: 0.7, periodMs: 2600, tilt: 7, eyeScale: 0.72, blinkMs: 2400 },
  angry: { amplitude: 0.9, periodMs: 2000, tilt: -7, eyeScale: 0.62, blinkMs: 2400 },
  sad: { amplitude: 0.7, periodMs: 4200, tilt: -4, eyeScale: 0.58, blinkMs: 4200 },
  laughing: { amplitude: 3.1, periodMs: 1100, tilt: 0, eyeScale: 0.78, blinkMs: 1800 },
  scared: { amplitude: 2.8, periodMs: 900, tilt: 0, eyeScale: 1.12, blinkMs: 1500 },
  playful: { amplitude: 3.0, periodMs: 1450, tilt: 8, eyeScale: 1.04, blinkMs: 2400 },
  drowsy: { amplitude: 0.4, periodMs: 4200, tilt: 0, eyeScale: 0.28, blinkMs: 5200 },
  bored: { amplitude: 0.35, periodMs: 3600, tilt: -8, eyeScale: 0.45, blinkMs: 4800 },
  proud: { amplitude: 1.7, periodMs: 3300, tilt: 4, eyeScale: 1, blinkMs: 3600 },
  shy: { amplitude: 0.9, periodMs: 3200, tilt: -8, eyeScale: 0.55, blinkMs: 3600 },
  surprised: { amplitude: 2.4, periodMs: 2200, tilt: 0, eyeScale: 1.2, blinkMs: 2200 },
  orbit: { amplitude: 1.9, periodMs: 3600, tilt: 10, eyeScale: 1, blinkMs: 3000 },
  radar: { amplitude: 1.9, periodMs: 1500, tilt: -10, eyeScale: 0.9, blinkMs: 2600 },
  progress: { amplitude: 1.7, periodMs: 2100, tilt: 0, eyeScale: 1, blinkMs: 3000 },
  spawning: { amplitude: 3.3, periodMs: 1100, tilt: 0, eyeScale: 1, blinkMs: 2200 },
  humming: { amplitude: 1.3, periodMs: 4600, tilt: 0, eyeScale: 0.9, blinkMs: 3600 },
  loading: { amplitude: 1.7, periodMs: 1600, tilt: 3, eyeScale: 0.9, blinkMs: 2800 },
  dictating: { amplitude: 1.9, periodMs: 1200, tilt: 0, eyeScale: 1, blinkMs: 2800 },
  writing: { amplitude: 1.8, periodMs: 1500, tilt: -4, eyeScale: 1, blinkMs: 2600 },
  sending: { amplitude: 2.0, periodMs: 1300, tilt: 3, eyeScale: 1, blinkMs: 2600 },
  receiving: { amplitude: 2.0, periodMs: 1300, tilt: -3, eyeScale: 1, blinkMs: 2600 },
  uploading: { amplitude: 2.1, periodMs: 1200, tilt: 0, eyeScale: 1, blinkMs: 2500 },
  notifying: { amplitude: 2.5, periodMs: 1000, tilt: 0, eyeScale: 1.08, blinkMs: 2200 },
  alerting: { amplitude: 2.3, periodMs: 900, tilt: -6, eyeScale: 1.08, blinkMs: 1800 },
  dragging: { amplitude: 2.4, periodMs: 1400, tilt: 5, eyeScale: 1, blinkMs: 2600 },
  bouncing: { amplitude: 4.2, periodMs: 1000, tilt: 0, eyeScale: 1, blinkMs: 2200 },
  "powering-down": { amplitude: 0.2, periodMs: 8000, tilt: 0, eyeScale: 0.18, blinkMs: 8000 },
};

function hashIdentity(value: string): number {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash = Math.imul(hash ^ value.charCodeAt(index), 16777619);
  }
  return hash >>> 0;
}

function iosGhostColor(identity: string): string {
  return IOS_GHOST_COLORS[hashIdentity(identity) % IOS_GHOST_COLORS.length];
}

function clothGhostPath(phase: number): string {
  const top = 8;
  const shoulder = 26;
  const hem = 80;
  const wave = 5.5;
  const drift = Math.sin(phase) * 1.8;
  const segment = 68 / 3;
  let path = `M${(16 + drift).toFixed(2)} ${hem} L16 ${shoulder} C17 13 34 ${top} 50 ${top} C66 ${top} 83 13 84 ${shoulder} L${(84 + drift).toFixed(2)} ${hem}`;
  for (let index = 3; index >= 1; index -= 1) {
    const right = 16 + segment * index;
    const left = right - segment;
    const local = phase + index * 0.9;
    const crest = hem + Math.sin(local) * wave;
    const end = hem + Math.sin(local + 0.7) * wave;
    path += ` Q${((left + right) * 0.5).toFixed(2)} ${(crest + 14).toFixed(2)} ${left.toFixed(2)} ${end.toFixed(2)}`;
  }
  return `${path} Z`;
}

function reducedMotion(): boolean {
  return typeof window !== "undefined" && window.matchMedia?.("(prefers-reduced-motion: reduce)").matches === true;
}

function documentCanAnimate(): boolean {
  if (typeof document === "undefined") return false;
  return document.visibilityState === "visible" && document.hasFocus();
}

function isLowEnergyState(state: BotMarkState): boolean {
  return state === "idle" || state === "sleeping" || state === "drowsy" || state === "bored" || state === "powering-down";
}

export const FabushiAvatarRuntime = forwardRef<FabushiAvatarRuntimeHandle, FabushiAvatarRuntimeProps>(
  function FabushiAvatarRuntime(
    {
      identity,
      state,
      size,
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
    const bodyRef = useRef<SVGPathElement>(null);
    const shineRef = useRef<SVGPathElement>(null);
    const eyesRef = useRef<SVGGElement>(null);
    const pointerGaze = useRef({ x: 0, y: 0 });
    const actionRef = useRef<{ kind: "spin" | "bounce" | "burst"; startedAt: number; durationMs: number } | null>(null);
    const motion = MOTION[state] ?? DEFAULT_MOTION;
    const baseColor = useMemo(() => iosGhostColor(identity), [identity]);

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
      const body = bodyRef.current;
      const shine = shineRef.current;
      const eyes = eyesRef.current;
      if (!face || !body || !shine || !eyes || typeof window === "undefined") return;

      let frame = 0;
      let lastPaint = 0;
      const startedAt = performance.now();
      const staticPath = clothGhostPath(0);

      const paintStatic = () => {
        body.setAttribute("d", staticPath);
        shine.setAttribute("d", staticPath);
        face.setAttribute("transform", `rotate(${motion.tilt * 0.2} 50 50)`);
        eyes.setAttribute("transform", `translate(0 0) scale(1 ${motion.eyeScale})`);
      };

      const shouldPause = () => paused || reducedMotion() || !documentCanAnimate();

      const tick = (now: number) => {
        if (shouldPause()) {
          paintStatic();
          frame = 0;
          return;
        }

        const minInterval = isLowEnergyState(state) ? 1000 / 15 : 1000 / 30;
        if (lastPaint && now - lastPaint < minInterval) {
          frame = window.requestAnimationFrame(tick);
          return;
        }
        lastPaint = now;

        const elapsed = now - startedAt;
        const phase = elapsed / motion.periodMs * TAU;
        const lift = Math.sin(phase) * motion.amplitude * (emphasis ? 1.2 : 1);
        const sway = Math.sin(phase * 0.72) * (1.7 + motion.tilt * 0.08);
        const path = clothGhostPath(phase);
        body.setAttribute("d", path);
        shine.setAttribute("d", path);

        const action = actionRef.current;
        let spin = 0;
        let bounce = 0;
        if (action) {
          const progress = Math.min(1, Math.max(0, (now - action.startedAt) / action.durationMs));
          const envelope = Math.sin(progress * Math.PI);
          if (action.kind === "spin" || action.kind === "burst") spin = progress * 360;
          if (action.kind === "bounce" || action.kind === "burst") bounce = envelope * 8;
          if (progress >= 1) actionRef.current = null;
        }

        const target = gaze ?? pointerGaze.current;
        const gx = Math.max(-1, Math.min(1, target?.x ?? Math.sin(phase * 0.48)));
        const gy = Math.max(-1, Math.min(1, target?.y ?? Math.cos(phase * 0.39)));
        const blinkWave = Math.sin(elapsed / Math.max(1000, motion.blinkMs) * TAU);
        const blinkScale = blinkWave > 0.985 ? 0.2 : motion.eyeScale;
        face.setAttribute("transform", `translate(0 ${(-lift - bounce).toFixed(2)}) rotate(${(sway + motion.tilt + spin).toFixed(2)} 50 50)`);
        eyes.setAttribute("transform", `translate(${(gx * 1.3).toFixed(2)} ${(gy * 0.85).toFixed(2)}) scale(1 ${blinkScale.toFixed(3)})`);
        frame = window.requestAnimationFrame(tick);
      };

      const resume = () => {
        document.documentElement.dataset.fabushiMotionPaused = documentCanAnimate() ? "false" : "true";
        if (shouldPause()) {
          if (frame) window.cancelAnimationFrame(frame);
          frame = 0;
          paintStatic();
          return;
        }
        if (!frame) frame = window.requestAnimationFrame(tick);
      };

      document.addEventListener("visibilitychange", resume);
      window.addEventListener("focus", resume);
      window.addEventListener("blur", resume);
      resume();
      return () => {
        document.removeEventListener("visibilitychange", resume);
        window.removeEventListener("focus", resume);
        window.removeEventListener("blur", resume);
        if (frame) window.cancelAnimationFrame(frame);
      };
    }, [emphasis, gaze, motion, paused, state]);

    const rootStyle: CSSProperties = {
      display: "block",
      width: size,
      height: size,
      overflow: "visible",
      userSelect: "none",
      WebkitUserSelect: "none",
    };

    return (
      <svg
        aria-hidden="true"
        data-avatar-style="ios-cloth-ghost"
        data-fabushi-avatar-runtime="v2"
        data-state={state}
        height={size}
        width={size}
        style={rootStyle}
        viewBox={VIEW_BOX}
        xmlns="http://www.w3.org/2000/svg"
      >
        <defs>
          <linearGradient id={`${gradientId}-body`} x1="0" x2="1" y1="0" y2="1">
            <stop offset="0" stopColor={baseColor} stopOpacity="0.98" />
            <stop offset="0.55" stopColor={baseColor} stopOpacity="0.86" />
            <stop offset="1" stopColor={baseColor} stopOpacity="0.98" />
          </linearGradient>
          <linearGradient id={`${gradientId}-shine`} x1="0" x2="1" y1="0" y2="1">
            <stop offset="0" stopColor="#ffffff" stopOpacity="0.24" />
            <stop offset="0.52" stopColor="#ffffff" stopOpacity="0" />
            <stop offset="1" stopColor="#000000" stopOpacity="0.10" />
          </linearGradient>
        </defs>
        <g ref={faceRef}>
          <path ref={bodyRef} d={clothGhostPath(0)} fill={`url(#${gradientId}-body)`} />
          <path ref={shineRef} d={clothGhostPath(0)} fill={`url(#${gradientId}-shine)`} />
          <g ref={eyesRef} fill={eyeColor}>
            <rect x="37.8" y="32.5" width="7.8" height="17" rx="3.9" />
            <rect x="54.4" y="32.5" width="7.8" height="17" rx="3.9" />
          </g>
        </g>
      </svg>
    );
  },
);
