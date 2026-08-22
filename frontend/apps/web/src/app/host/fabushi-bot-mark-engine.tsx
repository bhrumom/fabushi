import {
  forwardRef,
  useEffect,
  useId,
  useImperativeHandle,
  useMemo,
  useRef,
} from "react";

export type FabushiBotMarkEngineHandle = {
  spin: (turns?: number) => void;
  bounce: () => void;
  burst: () => void;
};

type Point = { x: number; y: number };
type Pose = { turn?: number; tilt?: number; roll?: number; scale?: number };
type FaceTune = {
  size?: number;
  gap?: number;
  height?: number;
  eyeWidth?: number;
  eyeHeight?: number;
};
type InkGradient = {
  from: string;
  to: string;
  angle?: number;
  fromPos?: number;
  toPos?: number;
};
type AccentMode = "none" | "pulse" | "orbit" | "alert" | "radar" | "progress";

type MotionProfile = {
  energy: number;
  pace: number;
  breath: number;
  swayX: number;
  swayY: number;
  roll: number;
  bounce: number;
  eyeOpen: number;
  eyeWidth: number;
  eyeY: number;
  eyeTilt: number;
  eyeSmile: number;
  gazeWander: number;
  mouth: number;
  roundMouth: number;
  cheek: number;
  blinkRate: number;
  accent: AccentMode;
};

export type FabushiBotMarkEngineProps = {
  botId: string;
  state: string;
  size: number;
  shapePath: string;
  shapeScale?: number;
  gazeTarget?: Point | null;
  followPointer?: boolean;
  emphasis?: boolean;
  spinSignal?: number;
  badgeColor?: string;
  paused?: boolean;
  pose?: Pose;
  poseHome?: Pose;
  faceTune?: FaceTune;
  eyeScale?: number;
  uniformEyes?: boolean;
  eyeTopology?: boolean;
  inkGradient?: InkGradient | null;
};

export type FabushiBotMarkRhythm = {
  breatheMs: number;
  orbitMs: number;
  pulseMs: number;
  blinkMs: number;
  delayMs: number;
};

type FrameListener = (timeMs: number, deltaSeconds: number) => void;

// One animation clock drives every mark. The engine writes SVG attributes directly,
// so a sidebar full of agents does not cause a React render on every animation frame.
const frameListeners = new Set<FrameListener>();
let motionFrameId: number | null = null;
let lastMotionFrameMs = 0;

function runMotionFrame(timeMs: number): void {
  const rawDelta = lastMotionFrameMs ? (timeMs - lastMotionFrameMs) / 1000 : 1 / 60;
  const deltaSeconds = Math.min(0.033, Math.max(1 / 240, rawDelta));
  lastMotionFrameMs = timeMs;
  for (const listener of frameListeners) listener(timeMs, deltaSeconds);
  if (frameListeners.size > 0) {
    motionFrameId = window.requestAnimationFrame(runMotionFrame);
  } else {
    motionFrameId = null;
    lastMotionFrameMs = 0;
  }
}

function subscribeMotionFrame(listener: FrameListener): () => void {
  frameListeners.add(listener);
  if (motionFrameId === null) motionFrameId = window.requestAnimationFrame(runMotionFrame);
  return () => {
    frameListeners.delete(listener);
    if (frameListeners.size === 0 && motionFrameId !== null) {
      window.cancelAnimationFrame(motionFrameId);
      motionFrameId = null;
      lastMotionFrameMs = 0;
    }
  };
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.max(minimum, Math.min(maximum, value));
}

function hashMotionIdentity(value: string): number {
  let hash = 0x6d2b79f5 ^ value.length;
  for (let index = 0; index < value.length; index += 1) {
    hash = Math.imul(hash ^ value.charCodeAt(index), 0x45d9f3b);
    hash = (hash << 13) | (hash >>> 19);
  }
  hash ^= hash >>> 16;
  hash = Math.imul(hash, 0x27d4eb2d);
  hash ^= hash >>> 15;
  return hash >>> 0;
}

function seededUnit(seed: number, salt: number): number {
  let value = (seed ^ Math.imul(salt + 1, 0x9e3779b1)) >>> 0;
  value ^= value >>> 16;
  value = Math.imul(value, 0x21f0aaad);
  value ^= value >>> 15;
  value = Math.imul(value, 0x735a2d97);
  value ^= value >>> 15;
  return (value >>> 0) / 0x100000000;
}

export function fabushiRhythmForBot(botId: string): FabushiBotMarkRhythm {
  const seed = hashMotionIdentity(`rhythm:${botId}`);
  const breatheMs = Math.round(4_400 + seededUnit(seed, 1) * 2_300);
  return {
    breatheMs,
    orbitMs: Math.round(breatheMs * (1.26 + seededUnit(seed, 2) * 0.34)),
    pulseMs: Math.round(breatheMs * (0.54 + seededUnit(seed, 3) * 0.2)),
    blinkMs: Math.round(2_700 + seededUnit(seed, 4) * 3_900),
    delayMs: -Math.round(seededUnit(seed, 5) * 3_400),
  };
}

const BASE: MotionProfile = {
  energy: 0.38, pace: 0.68, breath: 0.75, swayX: 0.65, swayY: 0.48,
  roll: 0.8, bounce: 0, eyeOpen: 0.9, eyeWidth: 1, eyeY: 0, eyeTilt: 0,
  eyeSmile: 0, gazeWander: 0.18, mouth: 0, roundMouth: 0, cheek: 0,
  blinkRate: 1, accent: "none",
};

function p(overrides: Partial<MotionProfile>): MotionProfile {
  return { ...BASE, ...overrides };
}

const SLEEP = p({ energy: 0.08, pace: 0.22, breath: 1, swayX: 0.12, swayY: 0.2, roll: 0.25, eyeOpen: 0.08, eyeWidth: 1.08, eyeY: 1.4, gazeWander: 0, blinkRate: 0 });
const WAKE = p({ energy: 0.72, pace: 0.72, breath: 0.7, swayY: 0.8, eyeOpen: 1.22, eyeWidth: 0.94, gazeWander: 0.12, blinkRate: 0.72 });
const LISTEN = p({ energy: 0.55, pace: 0.88, breath: 0.9, swayX: 0.2, swayY: 0.76, roll: 0.34, eyeOpen: 1.02, eyeWidth: 0.94, gazeWander: 0.05, blinkRate: 0.86 });
const THINK = p({ energy: 0.46, pace: 0.56, breath: 0.62, swayX: 0.46, swayY: 0.34, roll: 0.52, eyeOpen: 0.76, eyeWidth: 0.98, eyeY: -0.5, eyeTilt: -2.5, gazeWander: 0.62, blinkRate: 0.82, accent: "pulse" });
const SEARCH = p({ energy: 0.76, pace: 1.18, breath: 0.48, swayX: 0.92, swayY: 0.62, roll: 1.8, eyeOpen: 0.9, eyeWidth: 0.92, gazeWander: 0.82, blinkRate: 0.72, accent: "orbit" });
const WORK = p({ energy: 0.84, pace: 1.36, breath: 0.5, swayX: 0.9, swayY: 0.5, roll: 1.3, eyeOpen: 0.84, eyeWidth: 0.96, gazeWander: 0.12, blinkRate: 0.7, accent: "pulse" });
const JOY = p({ energy: 1.08, pace: 1.34, breath: 0.72, swayX: 0.64, swayY: 1.05, roll: 1.8, bounce: 0.86, eyeOpen: 0.46, eyeWidth: 1.08, eyeSmile: 0.96, gazeWander: 0.1, mouth: 0.88, cheek: 0.2, blinkRate: 0.92 });
const EXCITED = p({ ...JOY, energy: 1.24, pace: 1.5, bounce: 1.08, eyeOpen: 1.08, eyeSmile: 0.2, mouth: 0.55 });
const SURPRISED = p({ energy: 0.94, pace: 1.04, breath: 0.46, swayX: 0.36, swayY: 0.62, roll: 0.9, eyeOpen: 1.38, eyeWidth: 0.9, gazeWander: 0.04, roundMouth: 0.88, blinkRate: 0.58 });
const LOW = p({ energy: 0.16, pace: 0.28, breath: 0.94, swayX: 0.18, swayY: 0.25, roll: 0.3, eyeOpen: 0.36, eyeWidth: 1.07, eyeY: 1, gazeWander: 0.06, mouth: -0.14, blinkRate: 1.25 });
const CURIOUS = p({ energy: 0.52, pace: 0.54, breath: 0.62, swayX: 0.48, swayY: 0.38, roll: 0.58, eyeOpen: 1.04, eyeWidth: 0.95, eyeY: -0.4, eyeTilt: 2.5, gazeWander: 0.72, roundMouth: 0.42, blinkRate: 0.94 });
const SUSPICIOUS = p({ energy: 0.36, pace: 0.42, breath: 0.42, swayX: 0.34, swayY: 0.18, roll: 0.42, eyeOpen: 0.46, eyeWidth: 1.08, eyeY: 0.4, eyeTilt: -7, gazeWander: 0.48, mouth: -0.12, blinkRate: 0.62 });
const SAD = p({ energy: 0.22, pace: 0.34, breath: 0.9, swayX: 0.18, swayY: 0.28, roll: 0.32, eyeOpen: 0.56, eyeWidth: 0.96, eyeY: 0.9, eyeTilt: 7.5, gazeWander: 0.12, mouth: -0.66, blinkRate: 0.96 });
const SHY = p({ ...SAD, energy: 0.34, eyeOpen: 0.62, eyeTilt: 6, gazeWander: 0.28, mouth: 0.2, cheek: 0.92, blinkRate: 1.14 });
const ANGRY = p({ energy: 1.06, pace: 1.82, breath: 0.32, swayX: 1.25, swayY: 0.2, roll: 3.6, eyeOpen: 0.56, eyeWidth: 1.08, eyeTilt: -12, gazeWander: 0.02, mouth: -0.3, blinkRate: 0.54, accent: "alert" });
const ALERT = p({ ...ANGRY, energy: 1.12, eyeOpen: 0.72, eyeTilt: -10 });
const SCARED = p({ energy: 1.16, pace: 1.92, breath: 0.28, swayX: 1.42, swayY: 0.5, roll: 4.4, eyeOpen: 1.32, eyeWidth: 0.92, gazeWander: 0.12, roundMouth: 0.58, blinkRate: 0.5, accent: "alert" });
const ORBIT = p({ energy: 0.68, pace: 1.06, breath: 0.48, swayX: 0.74, swayY: 0.62, roll: 1.7, eyeOpen: 0.82, gazeWander: 0.66, blinkRate: 0.68, accent: "orbit" });
const RADAR = p({ energy: 0.76, pace: 1.28, breath: 0.4, swayX: 0.36, swayY: 0.3, roll: 0.8, eyeOpen: 0.9, gazeWander: 0.84, blinkRate: 0.58, accent: "radar" });
const PROGRESS = p({ energy: 0.58, pace: 0.94, breath: 0.44, swayX: 0.28, swayY: 0.32, roll: 0.65, eyeOpen: 0.78, gazeWander: 0.1, blinkRate: 0.64, accent: "progress" });
const POWER_DOWN = p({ ...SLEEP, energy: 0.04, pace: 0.16, eyeOpen: 0.05, eyeY: 1.6 });

function profileForState(state: string): MotionProfile {
  switch (state) {
    case "sleeping": return SLEEP;
    case "waking": case "spawning": return WAKE;
    case "listening": case "dictating": case "humming": return LISTEN;
    case "thinking": return THINK;
    case "searching": case "loading": return SEARCH;
    case "working": case "tool-running": case "writing": case "sending": case "receiving": case "uploading": case "notifying": case "dragging": return WORK;
    case "speaking": return p({ ...LISTEN, energy: 0.72, pace: 1.18, mouth: 0.72, eyeSmile: 0.18 });
    case "result": return p({ ...JOY, energy: 0.74, pace: 0.82, bounce: 0.28, mouth: 0.42 });
    case "error": return p({ ...ALERT, energy: 0.96, pace: 1.42, eyeTilt: -8, mouth: -0.46 });
    case "happy": case "laughing": case "celebrate": case "proud": return JOY;
    case "excited": case "playful": case "bouncing": return EXCITED;
    case "surprised": return SURPRISED;
    case "drowsy": case "bored": return LOW;
    case "curious": return CURIOUS;
    case "suspicious": case "confused": return SUSPICIOUS;
    case "sad": return SAD;
    case "shy": return SHY;
    case "angry": return ANGRY;
    case "alerting": return ALERT;
    case "scared": return SCARED;
    case "orbit": return ORBIT;
    case "radar": return RADAR;
    case "progress": return PROGRESS;
    case "powering-down": return POWER_DOWN;
    default: return BASE;
  }
}

export function fabushiAccentForState(state: string): "none" | "orbit" | "pulse" | "alert" {
  const accent = profileForState(state).accent;
  if (accent === "radar" || accent === "progress") return "orbit";
  return accent;
}

type SpringChannel = { value: number; velocity: number };
const channel = (value: number): SpringChannel => ({ value, velocity: 0 });

function springStep(spring: SpringChannel, target: number, dt: number, stiffness = 92, damping = 17): void {
  const acceleration = (target - spring.value) * stiffness - spring.velocity * damping;
  spring.velocity += acceleration * dt;
  spring.value += spring.velocity * dt;
}

function eyeLensPath(cx: number, cy: number, width: number, height: number, smile: number): string {
  const hw = Math.max(0.8, width / 2);
  const hh = Math.max(0.42, height / 2);
  const left = cx - hw;
  const right = cx + hw;
  const top = hh * (1 - smile * 0.12);
  const bottom = Math.max(0.36, hh * (1 - smile * 0.58));
  const lift = smile * hh * 0.72;
  return `M${left.toFixed(2)} ${cy.toFixed(2)} C${(left + hw * 0.28).toFixed(2)} ${(cy - top).toFixed(2)} ${(right - hw * 0.28).toFixed(2)} ${(cy - top + lift * 0.12).toFixed(2)} ${right.toFixed(2)} ${cy.toFixed(2)} C${(right - hw * 0.28).toFixed(2)} ${(cy + bottom - lift).toFixed(2)} ${(left + hw * 0.28).toFixed(2)} ${(cy + bottom - lift).toFixed(2)} ${left.toFixed(2)} ${cy.toFixed(2)}Z`;
}

function normalizedGazeForPoint(element: SVGSVGElement, point: Point): Point {
  const rect = element.getBoundingClientRect();
  const halfWidth = Math.max(1, rect.width / 2);
  const halfHeight = Math.max(1, rect.height / 2);
  return {
    x: clamp((point.x - (rect.left + halfWidth)) / halfWidth, -1, 1),
    y: clamp((point.y - (rect.top + halfHeight)) / halfHeight, -1, 1),
  };
}

function blinkAmountForTime(startedAt: number, timeMs: number): number {
  if (startedAt <= 0) return 0;
  const progress = (timeMs - startedAt) / 118;
  if (progress <= 0 || progress >= 1) return 0;
  if (progress < 0.38) {
    const close = progress / 0.38;
    return 1 - (1 - close) * (1 - close);
  }
  const open = (progress - 0.38) / 0.62;
  return 1 - open * open;
}

type PhysicsState = {
  x: SpringChannel; y: SpringChannel; roll: SpringChannel;
  scaleX: SpringChannel; scaleY: SpringChannel;
  gazeX: SpringChannel; gazeY: SpringChannel;
  eyeOpen: SpringChannel; eyeWidth: SpringChannel; eyeY: SpringChannel;
  eyeTilt: SpringChannel; eyeSmile: SpringChannel;
  mouth: SpringChannel; roundMouth: SpringChannel; cheek: SpringChannel;
  spin: SpringChannel; spinTarget: number;
  bounceY: SpringChannel; burst: SpringChannel;
  nextBlinkAt: number; blinkStartedAt: number;
  queuedSecondBlink: boolean; forceSecondBlink: boolean; randomCounter: number;
};

function createPhysics(): PhysicsState {
  return {
    x: channel(0), y: channel(0), roll: channel(0), scaleX: channel(1), scaleY: channel(1),
    gazeX: channel(0), gazeY: channel(0), eyeOpen: channel(BASE.eyeOpen), eyeWidth: channel(1),
    eyeY: channel(0), eyeTilt: channel(0), eyeSmile: channel(0), mouth: channel(0),
    roundMouth: channel(0), cheek: channel(0), spin: channel(0), spinTarget: 0,
    bounceY: channel(0), burst: channel(0), nextBlinkAt: 0, blinkStartedAt: 0,
    queuedSecondBlink: false, forceSecondBlink: false, randomCounter: 0,
  };
}

export const FabushiBotMarkEngine = forwardRef<FabushiBotMarkEngineHandle, FabushiBotMarkEngineProps>(
  function FabushiBotMarkEngine(
    {
      botId,
      state,
      size,
      shapePath,
      shapeScale = 1,
      gazeTarget = null,
      followPointer = false,
      emphasis = false,
      spinSignal = 0,
      badgeColor,
      paused = false,
      pose,
      poseHome,
      faceTune,
      eyeScale = 1,
      uniformEyes = true,
      eyeTopology = true,
      inkGradient = null,
    },
    ref,
  ) {
    const svgRef = useRef<SVGSVGElement | null>(null);
    const bodyRef = useRef<SVGGElement | null>(null);
    const leftEyeRef = useRef<SVGPathElement | null>(null);
    const rightEyeRef = useRef<SVGPathElement | null>(null);
    const topologyRef = useRef<SVGPathElement | null>(null);
    const mouthRef = useRef<SVGPathElement | null>(null);
    const roundMouthRef = useRef<SVGCircleElement | null>(null);
    const leftCheekRef = useRef<SVGCircleElement | null>(null);
    const rightCheekRef = useRef<SVGCircleElement | null>(null);
    const accentRingRef = useRef<SVGCircleElement | null>(null);
    const radarSweepRef = useRef<SVGLineElement | null>(null);
    const burstRingRef = useRef<SVGCircleElement | null>(null);
    const surfaceGradientRef = useRef<SVGRadialGradientElement | null>(null);
    const thoughtDotsRef = useRef<Array<SVGCircleElement | null>>([]);
    const physicsRef = useRef<PhysicsState>(createPhysics());
    const pointerGazeRef = useRef<Point | null>(null);
    const externalGazeRef = useRef<Point | null>(null);
    const visibleRef = useRef(true);
    const reducedMotionRef = useRef(false);
    const lastSpinSignalRef = useRef(spinSignal);
    const seed = useMemo(() => hashMotionIdentity(`motion:${botId}`), [botId]);
    const rhythm = useMemo(() => fabushiRhythmForBot(botId), [botId]);
    const uniqueId = useId().replace(/:/g, "");
    const clipId = `fabushi-mark-clip-${uniqueId}`;
    const surfaceId = `fabushi-mark-surface-${uniqueId}`;
    const shadeId = `fabushi-mark-shade-${uniqueId}`;
    const inkId = `fabushi-mark-ink-${uniqueId}`;

    const propsRef = useRef({
      state,
      shapeScale,
      emphasis,
      paused,
      pose,
      poseHome,
      faceTune,
      eyeScale,
      uniformEyes,
      eyeTopology,
    });
    propsRef.current = {
      state,
      shapeScale,
      emphasis,
      paused,
      pose,
      poseHome,
      faceTune,
      eyeScale,
      uniformEyes,
      eyeTopology,
    };

    useImperativeHandle(ref, () => ({
      spin(turns = 1) {
        physicsRef.current.spinTarget += clamp(turns, -4, 4) * 360;
      },
      bounce() {
        const physics = physicsRef.current;
        physics.bounceY.velocity -= 26;
        physics.burst.value = Math.max(physics.burst.value, 0.24);
      },
      burst() {
        const physics = physicsRef.current;
        physics.burst.value = 1;
        physics.burst.velocity = 0;
      },
    }), []);

    useEffect(() => {
      if (lastSpinSignalRef.current !== spinSignal) {
        if (spinSignal !== 0) physicsRef.current.spinTarget += 360;
        lastSpinSignalRef.current = spinSignal;
      }
    }, [spinSignal]);

    useEffect(() => {
      const media = window.matchMedia?.("(prefers-reduced-motion: reduce)");
      if (!media) return undefined;
      const sync = () => { reducedMotionRef.current = media.matches; };
      sync();
      media.addEventListener?.("change", sync);
      return () => media.removeEventListener?.("change", sync);
    }, []);

    useEffect(() => {
      const element = svgRef.current;
      if (!element || typeof IntersectionObserver === "undefined") return undefined;
      const observer = new IntersectionObserver((entries) => {
        visibleRef.current = entries.some((entry) => entry.isIntersecting);
      }, { rootMargin: "120px" });
      observer.observe(element);
      return () => observer.disconnect();
    }, []);

    useEffect(() => {
      if (followPointer) return undefined;
      const element = svgRef.current;
      if (!element || !gazeTarget) {
        externalGazeRef.current = null;
        return undefined;
      }
      externalGazeRef.current = normalizedGazeForPoint(element, gazeTarget);
      return undefined;
    }, [followPointer, gazeTarget]);

    useEffect(() => {
      if (!followPointer) {
        pointerGazeRef.current = null;
        return undefined;
      }
      const onPointerMove = (event: PointerEvent) => {
        const element = svgRef.current;
        if (!element) return;
        pointerGazeRef.current = normalizedGazeForPoint(element, { x: event.clientX, y: event.clientY });
      };
      const onPointerLeave = () => { pointerGazeRef.current = null; };
      window.addEventListener("pointermove", onPointerMove, { passive: true });
      document.documentElement.addEventListener("pointerleave", onPointerLeave);
      return () => {
        window.removeEventListener("pointermove", onPointerMove);
        document.documentElement.removeEventListener("pointerleave", onPointerLeave);
      };
    }, [followPointer]);

    useEffect(() => {
      const phaseA = seededUnit(seed, 10) * Math.PI * 2;
      const phaseB = seededUnit(seed, 11) * Math.PI * 2;
      const phaseC = seededUnit(seed, 12) * Math.PI * 2;
      const phaseD = seededUnit(seed, 13) * Math.PI * 2;

      return subscribeMotionFrame((timeMs, deltaSeconds) => {
        if (!visibleRef.current) return;

        const currentProps = propsRef.current;
        const profileValue = profileForState(currentProps.state);
        const physics = physicsRef.current;
        const timeSeconds = timeMs / 1000;
        const reduced = reducedMotionRef.current;
        const continuousMotion = currentProps.paused || reduced ? 0 : 1;
        const springDelta = currentProps.paused ? 0 : deltaSeconds;

        const baseWave = Math.sin(timeSeconds * (0.86 + profileValue.pace * 0.12) + phaseA);
        const secondaryWave = Math.sin(timeSeconds * (1.37 + profileValue.pace * 0.22) + phaseB);
        const taskWave = Math.sin(timeSeconds * (2.1 + profileValue.pace * 1.14) + phaseC);
        const organic = baseWave * 0.62 + secondaryWave * 0.26 + Math.sin(timeSeconds * 0.43 + phaseD) * 0.12;
        const alertJitter = profileValue.accent === "alert" ? Math.sin(timeSeconds * 21 + phaseB) : 0;
        const joyLift = profileValue.bounce > 0
          ? Math.max(0, Math.sin(timeSeconds * (2.5 + profileValue.pace * 1.4) + phaseC)) * profileValue.bounce
          : 0;

        springStep(
          physics.x,
          continuousMotion * (organic * profileValue.swayX * profileValue.energy + taskWave * profileValue.swayX * 0.3 + alertJitter * 1.35),
          springDelta,
          72 + profileValue.energy * 34,
          15,
        );
        springStep(
          physics.y,
          continuousMotion * (-profileValue.breath * (0.35 + baseWave * 0.28) + secondaryWave * profileValue.swayY * 0.42 - joyLift * 2.6),
          springDelta,
          78 + profileValue.energy * 30,
          15,
        );
        springStep(
          physics.roll,
          continuousMotion * (organic * profileValue.roll + taskWave * profileValue.roll * 0.36 + alertJitter * 2.2),
          springDelta,
          74 + profileValue.energy * 42,
          16,
        );
        springStep(physics.bounceY, 0, springDelta, 126, 15.5);
        springStep(physics.burst, 0, springDelta, 78, 19);
        physics.burst.value = clamp(physics.burst.value, -0.03, 1.2);

        const homePose = ["idle", "sleeping", "drowsy", "powering-down"].includes(currentProps.state)
          ? currentProps.poseHome
          : currentProps.pose;
        const poseScale = clamp((homePose?.scale ?? 1) * currentProps.shapeScale, 0.76, 1.28);
        const turn = clamp(homePose?.turn ?? 0, -70, 70);
        const tilt = clamp(homePose?.tilt ?? 0, -50, 50);
        const staticRoll = (homePose?.roll ?? 0) * 0.16;
        const perspectiveX = 1 - Math.abs(turn) / 420;
        const perspectiveY = 1 - Math.abs(tilt) / 680;
        const breathingScale = continuousMotion * baseWave * profileValue.breath * 0.008;
        const taskSquash = continuousMotion * taskWave * profileValue.bounce * 0.012;
        const burstScale = Math.max(0, physics.burst.value) * 0.075;
        springStep(physics.scaleX, poseScale * perspectiveX * (1 + breathingScale + taskSquash + burstScale), springDelta, 96, 18);
        springStep(physics.scaleY, poseScale * perspectiveY * (1 - breathingScale * 0.72 - taskSquash * 0.56 + burstScale), springDelta, 96, 18);
        springStep(physics.spin, physics.spinTarget, springDelta, 48, 13.5);

        const directGaze = followPointer ? pointerGazeRef.current : externalGazeRef.current;
        const wander = continuousMotion * profileValue.gazeWander;
        const gazeTargetX = directGaze?.x
          ?? (Math.sin(timeSeconds * 0.54 + phaseB) * 0.62 + Math.sin(timeSeconds * 0.23 + phaseD) * 0.38) * wander;
        const gazeTargetY = directGaze?.y
          ?? (Math.sin(timeSeconds * 0.41 + phaseC) * 0.72 + Math.cos(timeSeconds * 0.19 + phaseA) * 0.28) * wander * 0.7;
        springStep(physics.gazeX, clamp(gazeTargetX, -1, 1), springDelta, directGaze ? 118 : 46, directGaze ? 20 : 13);
        springStep(physics.gazeY, clamp(gazeTargetY, -1, 1), springDelta, directGaze ? 118 : 46, directGaze ? 20 : 13);

        springStep(physics.eyeOpen, profileValue.eyeOpen, springDelta, 118, 20);
        springStep(physics.eyeWidth, profileValue.eyeWidth, springDelta, 104, 19);
        springStep(physics.eyeY, profileValue.eyeY, springDelta, 94, 18);
        springStep(physics.eyeTilt, profileValue.eyeTilt, springDelta, 104, 18);
        springStep(physics.eyeSmile, profileValue.eyeSmile, springDelta, 104, 19);
        springStep(physics.mouth, profileValue.mouth, springDelta, 96, 18);
        springStep(physics.roundMouth, profileValue.roundMouth, springDelta, 96, 18);
        springStep(physics.cheek, profileValue.cheek, springDelta, 88, 17);

        if (!currentProps.paused && !reduced && profileValue.blinkRate > 0) {
          if (physics.nextBlinkAt === 0) {
            physics.randomCounter += 1;
            physics.nextBlinkAt = timeMs + rhythm.blinkMs * (0.72 + seededUnit(seed, physics.randomCounter) * 0.62) / profileValue.blinkRate;
          }
          if (physics.blinkStartedAt === 0 && timeMs >= physics.nextBlinkAt) {
            physics.blinkStartedAt = timeMs;
            if (!physics.forceSecondBlink) {
              physics.randomCounter += 1;
              physics.queuedSecondBlink = seededUnit(seed, physics.randomCounter) > 0.84;
            }
          }
          if (physics.blinkStartedAt > 0 && timeMs - physics.blinkStartedAt > 118) {
            physics.blinkStartedAt = 0;
            if (physics.queuedSecondBlink) {
              physics.queuedSecondBlink = false;
              physics.forceSecondBlink = true;
              physics.nextBlinkAt = timeMs + 150;
            } else {
              physics.forceSecondBlink = false;
              physics.randomCounter += 1;
              physics.nextBlinkAt = timeMs + rhythm.blinkMs * (0.68 + seededUnit(seed, physics.randomCounter) * 0.74) / profileValue.blinkRate;
            }
          }
        } else {
          physics.blinkStartedAt = 0;
          physics.nextBlinkAt = 0;
          physics.queuedSecondBlink = false;
          physics.forceSecondBlink = false;
        }

        const blink = blinkAmountForTime(physics.blinkStartedAt, timeMs);
        const faceScale = clamp((currentProps.faceTune?.size ?? 1) * currentProps.eyeScale, 0.66, 1.42);
        const eyeGap = 17.2 * (currentProps.faceTune?.gap ?? 1) * faceScale;
        const eyeWidth = 8.3 * physics.eyeWidth.value * (currentProps.faceTune?.eyeWidth ?? 1) * faceScale;
        const eyeHeight = Math.max(0.72, 7.8 * physics.eyeOpen.value * (1 - blink * 0.9) * (currentProps.faceTune?.eyeHeight ?? 1) * (currentProps.faceTune?.height ?? 1) * faceScale);
        const faceShiftX = turn * 0.035 + physics.gazeX.value * 3.2;
        const eyeCenterY = 49 + tilt * 0.022 + physics.eyeY.value + physics.gazeY.value * 2.55;
        const leftX = 50 - eyeGap / 2 + faceShiftX;
        const rightX = 50 + eyeGap / 2 + faceShiftX;
        const rightEyeScale = currentProps.uniformEyes ? 1 : 0.92;
        const rightEyeHeightScale = currentProps.uniformEyes ? 1 : 1.07;

        if (bodyRef.current) {
          const centerX = 50 + physics.x.value;
          const centerY = 50 + physics.y.value + physics.bounceY.value;
          bodyRef.current.setAttribute(
            "transform",
            `translate(${centerX.toFixed(2)} ${centerY.toFixed(2)}) rotate(${(staticRoll + physics.roll.value + physics.spin.value).toFixed(2)}) skewY(${(turn * 0.052).toFixed(2)}) scale(${physics.scaleX.value.toFixed(4)} ${physics.scaleY.value.toFixed(4)}) translate(-50 -50)`,
          );
        }

        if (leftEyeRef.current) {
          leftEyeRef.current.setAttribute("d", eyeLensPath(leftX, eyeCenterY, eyeWidth, eyeHeight, physics.eyeSmile.value));
          leftEyeRef.current.setAttribute("transform", `rotate(${physics.eyeTilt.value.toFixed(2)} ${leftX.toFixed(2)} ${eyeCenterY.toFixed(2)})`);
        }
        if (rightEyeRef.current) {
          rightEyeRef.current.setAttribute("d", eyeLensPath(rightX, eyeCenterY, eyeWidth * rightEyeScale, eyeHeight * rightEyeHeightScale, physics.eyeSmile.value));
          rightEyeRef.current.setAttribute("transform", `rotate(${physics.eyeTilt.value.toFixed(2)} ${rightX.toFixed(2)} ${eyeCenterY.toFixed(2)})`);
        }
        if (topologyRef.current) {
          topologyRef.current.setAttribute("d", `M${(leftX + eyeWidth * 0.54).toFixed(2)} ${eyeCenterY.toFixed(2)} Q50 ${(eyeCenterY + 1.2 - physics.eyeSmile.value * 2.2).toFixed(2)} ${(rightX - eyeWidth * 0.54).toFixed(2)} ${eyeCenterY.toFixed(2)}`);
          topologyRef.current.setAttribute("opacity", currentProps.eyeTopology ? (0.075 + profileValue.energy * 0.035).toFixed(3) : "0");
        }
        if (mouthRef.current) {
          const amount = physics.mouth.value;
          mouthRef.current.setAttribute("d", `M40.5 65.5 Q50 ${(66.5 + amount * 5.2).toFixed(2)} 59.5 65.5`);
          mouthRef.current.setAttribute("opacity", clamp(Math.abs(amount) * 0.74, 0, 0.78).toFixed(3));
        }
        if (roundMouthRef.current) {
          roundMouthRef.current.setAttribute("r", (1.3 + physics.roundMouth.value * 2.1).toFixed(2));
          roundMouthRef.current.setAttribute("opacity", clamp(physics.roundMouth.value * 0.78, 0, 0.78).toFixed(3));
        }
        const cheekOpacity = clamp(physics.cheek.value * 0.52, 0, 0.52).toFixed(3);
        leftCheekRef.current?.setAttribute("opacity", cheekOpacity);
        rightCheekRef.current?.setAttribute("opacity", cheekOpacity);

        const accent = profileValue.accent;
        if (accentRingRef.current) {
          const orbitPhase = timeSeconds * (1.4 + profileValue.pace * 0.38) + phaseA;
          let radius = 43;
          let opacity = currentProps.emphasis ? 0.22 : 0;
          let dashArray = "none";
          let dashOffset = 0;
          let stroke = "var(--fg)";
          if (accent === "pulse") {
            radius = 42.5 + Math.sin(orbitPhase * 1.55) * 2.5;
            opacity = 0.18 + (Math.sin(orbitPhase * 1.55) + 1) * 0.11;
          } else if (accent === "orbit") {
            radius = 44; opacity = 0.34; dashArray = "6 7"; dashOffset = -timeSeconds * 15;
          } else if (accent === "radar") {
            radius = 44; opacity = 0.3; dashArray = "2 6"; dashOffset = -timeSeconds * 10;
          } else if (accent === "progress") {
            radius = 44; opacity = 0.38; dashArray = "72 205"; dashOffset = -timeSeconds * 38;
          } else if (accent === "alert") {
            radius = 43 + Math.sin(timeSeconds * 7.2) * 2.2;
            opacity = 0.35 + (Math.sin(timeSeconds * 7.2) + 1) * 0.17;
            stroke = "#ff5c6f";
          }
          accentRingRef.current.setAttribute("r", radius.toFixed(2));
          accentRingRef.current.setAttribute("opacity", clamp(opacity, 0, 0.72).toFixed(3));
          accentRingRef.current.setAttribute("stroke-dasharray", dashArray);
          accentRingRef.current.setAttribute("stroke-dashoffset", dashOffset.toFixed(2));
          accentRingRef.current.setAttribute("stroke", stroke);
        }
        if (radarSweepRef.current) {
          const showSweep = accent === "radar" || currentProps.state === "searching";
          radarSweepRef.current.setAttribute("opacity", showSweep ? "0.38" : "0");
          radarSweepRef.current.setAttribute("transform", `rotate(${((timeSeconds * 92 + seededUnit(seed, 22) * 360) % 360).toFixed(2)} 50 50)`);
        }
        if (burstRingRef.current) {
          const burst = clamp(physics.burst.value, 0, 1);
          burstRingRef.current.setAttribute("r", (42 + (1 - burst) * 10).toFixed(2));
          burstRingRef.current.setAttribute("opacity", (burst * 0.54).toFixed(3));
        }
        if (surfaceGradientRef.current) {
          const lightX = clamp(31 + physics.gazeX.value * 5 - turn * 0.08 + organic * 1.8 * continuousMotion, 18, 46);
          const lightY = clamp(21 + physics.gazeY.value * 4 - tilt * 0.08 + baseWave * 1.4 * continuousMotion, 12, 38);
          surfaceGradientRef.current.setAttribute("fx", `${lightX.toFixed(1)}%`);
          surfaceGradientRef.current.setAttribute("fy", `${lightY.toFixed(1)}%`);
        }

        const thinking = currentProps.state === "thinking" ? 1 : 0;
        thoughtDotsRef.current.forEach((dot, index) => {
          if (!dot) return;
          const wave = (Math.sin(timeSeconds * 2.3 + index * 1.15 + phaseD) + 1) / 2;
          dot.setAttribute("opacity", (thinking * (0.1 + wave * 0.38)).toFixed(3));
          dot.setAttribute("transform", `translate(0 ${(-wave * (1.2 + index * 0.45)).toFixed(2)})`);
        });
      });
    }, [followPointer, rhythm.blinkMs, seed]);

    const bodyFill = inkGradient ? `url(#${inkId})` : "var(--fg)";

    return (
      <svg
        ref={svgRef}
        viewBox="0 0 100 100"
        width={size}
        height={size}
        focusable="false"
        aria-hidden="true"
        data-engine="fabushi-motion-v2"
        style={{ overflow: "visible", display: "block" }}
      >
        <defs>
          <clipPath id={clipId}><path d={shapePath} /></clipPath>
          <radialGradient ref={surfaceGradientRef} id={surfaceId} cx="34%" cy="26%" r="72%" fx="31%" fy="21%">
            <stop offset="0%" stopColor="#ffffff" stopOpacity="0.34" />
            <stop offset="26%" stopColor="#ffffff" stopOpacity="0.11" />
            <stop offset="62%" stopColor="#ffffff" stopOpacity="0.025" />
            <stop offset="100%" stopColor="#ffffff" stopOpacity="0" />
          </radialGradient>
          <linearGradient id={shadeId} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="#000000" stopOpacity="0" />
            <stop offset="58%" stopColor="#000000" stopOpacity="0.015" />
            <stop offset="100%" stopColor="#000000" stopOpacity="0.22" />
          </linearGradient>
          {inkGradient ? (
            <linearGradient id={inkId} x1="0" y1="0" x2="1" y2="1" gradientTransform={`rotate(${inkGradient.angle ?? 45} .5 .5)`}>
              <stop offset={`${inkGradient.fromPos ?? 0}%`} stopColor={inkGradient.from} />
              <stop offset={`${inkGradient.toPos ?? 100}%`} stopColor={inkGradient.to} />
            </linearGradient>
          ) : null}
        </defs>

        <circle ref={accentRingRef} cx="50" cy="50" r="43" fill="none" stroke="var(--fg)" strokeWidth="1.35" opacity="0" />
        <line ref={radarSweepRef} x1="50" y1="50" x2="50" y2="8" stroke="var(--fg)" strokeWidth="1.2" strokeLinecap="round" opacity="0" />

        <g ref={bodyRef}>
          <path d={shapePath} fill="var(--fg)" opacity="0.12" transform="translate(2.2 3.2) scale(.982)" />
          <path d={shapePath} fill={bodyFill} />
          <path d={shapePath} fill={`url(#${surfaceId})`} clipPath={`url(#${clipId})`} opacity={emphasis ? 0.82 : 0.64} />
          <path d={shapePath} fill={`url(#${shadeId})`} clipPath={`url(#${clipId})`} opacity="0.55" />
          <path d={shapePath} fill="none" stroke="#ffffff" strokeWidth="0.75" strokeOpacity="0.13" />

          <path ref={topologyRef} d="" fill="none" stroke="var(--bg)" strokeWidth="1.15" strokeLinecap="round" opacity="0.08" />
          <path ref={leftEyeRef} d="M37 49h7v4h-7z" fill="var(--bg)" />
          <path ref={rightEyeRef} d="M56 49h7v4h-7z" fill="var(--bg)" />
          <circle ref={leftCheekRef} cx="31" cy="60" r="2.7" fill="#ff7d9c" opacity="0" />
          <circle ref={rightCheekRef} cx="69" cy="60" r="2.7" fill="#ff7d9c" opacity="0" />
          <path ref={mouthRef} d="M40.5 65.5 Q50 65.5 59.5 65.5" fill="none" stroke="var(--bg)" strokeWidth="2.2" strokeLinecap="round" opacity="0" />
          <circle ref={roundMouthRef} cx="50" cy="66.5" r="1.3" fill="var(--bg)" opacity="0" />
          <circle ref={(node) => { thoughtDotsRef.current[0] = node; }} cx="69" cy="31" r="1.8" fill="var(--bg)" opacity="0" />
          <circle ref={(node) => { thoughtDotsRef.current[1] = node; }} cx="74.5" cy="25" r="1.35" fill="var(--bg)" opacity="0" />
          <circle ref={(node) => { thoughtDotsRef.current[2] = node; }} cx="78.5" cy="19.5" r="0.9" fill="var(--bg)" opacity="0" />
        </g>

        <circle ref={burstRingRef} cx="50" cy="50" r="42" fill="none" stroke="var(--fg)" strokeWidth="1.6" opacity="0" />
        {badgeColor ? <circle cx="82" cy="80" r="7" fill={badgeColor} stroke="var(--bg)" strokeWidth="2" /> : null}
      </svg>
    );
  },
);
