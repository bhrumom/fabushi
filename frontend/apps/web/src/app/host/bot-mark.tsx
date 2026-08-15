import {
  forwardRef,
  useCallback,
  useEffect,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
} from "react";
import { GrokBotMarkEngine } from "./grok-bot-mark-engine";
import styles from "./host.module.css";

export type BotMarkState =
  | "sleeping"
  | "waking"
  | "idle"
  | "listening"
  | "thinking"
  | "searching"
  | "working"
  | "excited"
  | "surprised"
  | "suspicious"
  | "angry"
  | "drowsy"
  | "happy"
  | "curious"
  | "confused"
  | "bored"
  | "proud"
  | "shy"
  | "sad"
  | "laughing"
  | "scared"
  | "playful"
  | "celebrate"
  | "orbit"
  | "radar"
  | "progress"
  | "spawning"
  | "humming"
  | "loading"
  | "dictating"
  | "writing"
  | "sending"
  | "receiving"
  | "uploading"
  | "notifying"
  | "alerting"
  | "dragging"
  | "bouncing"
  | "powering-down";

export type BotMarkShape =
  | "blob"
  | "pebble"
  | "bean"
  | "egg"
  | "squircle"
  | "tablet"
  | "capsule"
  | "cylinder"
  | "hex"
  | "gem"
  | "crystal"
  | "wedge"
  | "shield"
  | "dome"
  | "arch"
  | "cloud"
  | "teardrop"
  | "leaf";

export type BotMarkColor =
  | "black"
  | "brown"
  | "red"
  | "orange"
  | "yellow"
  | "green"
  | "cyan"
  | "blue"
  | "violet"
  | "magenta"
  | "gray";

export type BotMarkHandle = {
  spin: (turns?: number) => void;
  bounce: () => void;
  burst: () => void;
};

type GazePoint = { x: number; y: number };
type BotMarkPose = { turn?: number; tilt?: number; roll?: number; scale?: number };
type BotMarkFaceTune = {
  size?: number;
  gap?: number;
  height?: number;
  eyeWidth?: number;
  eyeHeight?: number;
};
type BotMarkInkGradient = {
  from: string;
  to: string;
  angle?: number;
  fromPos?: number;
  toPos?: number;
};

type BotMarkProps = {
  botId: string;
  state?: BotMarkState;
  size?: number;
  className?: string;
  label?: string;
  children?: ReactNode;
  gazeTarget?: GazePoint | null;
  followPointer?: boolean;
  emphasis?: boolean;
  spinSignal?: number;
  badgeColor?: string;
  paused?: boolean;
  shape?: BotMarkShape;
  color?: BotMarkColor;
  eyeColor?: string;
  pose?: BotMarkPose;
  poseHome?: BotMarkPose;
  faceTune?: BotMarkFaceTune;
  eyeScale?: number;
  uniformEyes?: boolean;
  eyeTopology?: boolean;
  inkGradient?: BotMarkInkGradient | null;
};

const IDENTITY_SHAPES: readonly BotMarkShape[] = [
  "blob",
  "pebble",
  "squircle",
  "tablet",
  "wedge",
  "hex",
  "cloud",
  "teardrop",
];

const COLORS: readonly BotMarkColor[] = [
  "brown",
  "red",
  "orange",
  "yellow",
  "green",
  "cyan",
  "blue",
  "violet",
  "magenta",
  "gray",
];

const COLOR_VALUES: Record<BotMarkColor, { light: string; dark: string }> = {
  black: { light: "#000000", dark: "#FFFFFF" },
  brown: { light: "#A27952", dark: "#855C36" },
  red: { light: "#FF3E51", dark: "#E02135" },
  orange: { light: "#FF781C", dark: "#FF6700" },
  yellow: { light: "#FFAF38", dark: "#FF9800" },
  green: { light: "#00C972", dark: "#009957" },
  cyan: { light: "#1CC3B0", dark: "#00A592" },
  blue: { light: "#2A92FE", dark: "#0E74E0" },
  violet: { light: "#A97EFE", dark: "#804EE0" },
  magenta: { light: "#FF5EB1", dark: "#E02A88" },
  gray: { light: "#959595", dark: "#777777" },
};

const SHAPE_SCALE: Record<BotMarkShape, number> = {
  blob: 0.92,
  pebble: 0.96,
  bean: 1,
  egg: 1,
  squircle: 0.84,
  tablet: 1,
  capsule: 1,
  cylinder: 1,
  hex: 0.94,
  gem: 1,
  crystal: 1,
  wedge: 0.94,
  shield: 1,
  dome: 1,
  arch: 1,
  cloud: 1,
  teardrop: 1,
  leaf: 1,
};

const FACE_TUNE = {
  size: 0.86,
  gap: 1.18,
  height: 1,
  eyeWidth: 0.96,
  eyeHeight: 0.92,
} as const;

const POSE = { turn: 17, tilt: -14, roll: 29 } as const;
const POSE_HOME = { turn: 33, tilt: -19, roll: 38 } as const;
const MODEL_SCALE = 259 / 229;

function fnv1a(value: string): number {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function seededRandom(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 1831565813) | 0;
    let value = Math.imul(state ^ (state >>> 15), 1 | state);
    value = (value + Math.imul(value ^ (value >>> 7), 61 | value)) ^ value;
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

function identityColorIndex(botId: string): number {
  const mixed = (fnv1a(botId) ^ Math.imul(1, 2654435769)) >>> 0;
  const random = seededRandom((mixed ^ Math.imul(1, 2654435769)) >>> 0);
  return Math.floor(random() * COLORS.length);
}

function identityShapeHash(botId: string): number {
  let hash = fnv1a(botId);
  hash = Math.imul(hash ^ (hash >>> 16), 73244475);
  hash = Math.imul(hash ^ (hash >>> 13), 3266489909);
  return (hash ^ (hash >>> 16)) >>> 0;
}

export function botMarkShape(botId: string): BotMarkShape {
  return IDENTITY_SHAPES[identityShapeHash(botId) % IDENTITY_SHAPES.length] ?? "blob";
}

export function botMarkShapeIndex(botId: string): number {
  return identityShapeHash(botId) % IDENTITY_SHAPES.length;
}

export function botMarkColorId(botId: string): BotMarkColor {
  return COLORS[identityColorIndex(botId)] ?? "brown";
}

export function botMarkColor(botId: string): string {
  const value = COLOR_VALUES[botMarkColorId(botId)];
  return `light-dark(${value.light}, ${value.dark})`;
}

function pointerTargetForRect(rect: DOMRect, point: GazePoint): GazePoint {
  const centerX = rect.left + rect.width / 2;
  const centerY = rect.top + rect.height / 2;
  const deltaX = point.x - centerX;
  const deltaY = point.y - centerY;
  const distance = Math.min(
    1,
    Math.sqrt(Math.hypot(deltaX, deltaY) / Math.max(rect.width * 2, 1)),
  );
  const angle = Math.atan2(deltaY, deltaX);
  return {
    x: centerX + 0.6 * (14 / 22) * distance * Math.cos(angle) * rect.width,
    y: centerY + 0.6 * distance * Math.sin(angle) * rect.height,
  };
}

export const BotMark = forwardRef<BotMarkHandle, BotMarkProps>(function BotMark(
  {
    botId,
    state = "idle",
    size = 38,
    className = "",
    label,
    children,
    gazeTarget = null,
    followPointer = false,
    emphasis = false,
    spinSignal = 0,
    badgeColor,
    paused = false,
    shape: shapeOverride,
    color: colorOverride,
    eyeColor,
    pose,
    poseHome,
    faceTune,
    eyeScale,
    uniformEyes = true,
    eyeTopology = true,
    inkGradient = null,
  },
  ref,
) {
  const wrapperRef = useRef<HTMLSpanElement | null>(null);
  const [pointerGaze, setPointerGaze] = useState<GazePoint | null>(null);
  const shape = shapeOverride ?? botMarkShape(botId);
  const color = colorOverride ?? botMarkColorId(botId);
  const colorValue = COLOR_VALUES[color];
  const shapeScale = SHAPE_SCALE[shape];

  const updateExternalGaze = useCallback(() => {
    const element = wrapperRef.current;
    if (!element || !gazeTarget) {
      setPointerGaze(null);
      return;
    }
    const rect = element.getBoundingClientRect();
    if (rect.width > 0 && rect.height > 0) {
      setPointerGaze(pointerTargetForRect(rect, gazeTarget));
    }
  }, [gazeTarget]);

  useEffect(() => {
    if (!followPointer) {
      updateExternalGaze();
      return;
    }

    const onPointerMove = (event: PointerEvent) => {
      const element = wrapperRef.current;
      if (!element) return;
      const rect = element.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) return;
      setPointerGaze(pointerTargetForRect(rect, { x: event.clientX, y: event.clientY }));
    };
    const onPointerLeave = () => setPointerGaze(null);

    window.addEventListener("pointermove", onPointerMove, { passive: true });
    document.documentElement.addEventListener("pointerleave", onPointerLeave);
    return () => {
      window.removeEventListener("pointermove", onPointerMove);
      document.documentElement.removeEventListener("pointerleave", onPointerLeave);
    };
  }, [followPointer, updateExternalGaze]);

  const style = {
    width: size,
    height: size,
    "--bot-mark-size": `${size}px`,
    "--fg": `light-dark(${colorValue.light}, ${colorValue.dark})`,
    "--bg": eyeColor ?? "var(--bot-mark-eye-color, var(--app, #0b0b0b))",
  } as CSSProperties;

  return (
    <span
      ref={wrapperRef}
      className={`${styles.botMark} ${className}`.trim()}
      data-bot-id={botId}
      data-grok-state={state}
      data-paused={paused || undefined}
      data-shape={shape}
      data-color={color}
      style={style}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      role={label ? "img" : undefined}
    >
      <GrokBotMarkEngine
        ref={ref}
        state={state}
        shape={shape}
        size={size}
        gazeTarget={pointerGaze}
        emphasis={emphasis}
        spinSignal={spinSignal}
        badgeColor={badgeColor}
        paused={paused}
        faceTune={{ ...FACE_TUNE, ...faceTune }}
        eyeTopology={eyeTopology}
        pose={{
          ...POSE,
          ...pose,
          scale: pose?.scale ?? shapeScale * MODEL_SCALE,
        }}
        poseHome={{ ...POSE_HOME, ...poseHome }}
        uniformEyes={uniformEyes}
        eyeScale={eyeScale ?? SHAPE_SCALE.blob / shapeScale}
        inkGradient={inkGradient ?? undefined}
      />
      {children}
    </span>
  );
});

export function botMarkStateFromActivity(
  activity: { kind?: string; title?: string; detail?: string } | undefined,
): BotMarkState {
  if (!activity) return "thinking";
  const haystack = `${activity.kind ?? ""} ${activity.title ?? ""} ${activity.detail ?? ""}`.toLowerCase();

  if (/alert|warn|error|approval|permission|警告|错误|报错|审批|授权/.test(haystack)) {
    return "alerting";
  }
  if (/notify|notification|remind|通知|提醒/.test(haystack)) {
    return "notifying";
  }
  if (/upload|上传/.test(haystack)) {
    return "uploading";
  }
  if (/download|load|fetch|生成图片|下载|加载|获取文件/.test(haystack)) {
    return "loading";
  }
  if (/dictat|speech|voice|audio|听写|语音|录音/.test(haystack)) {
    return "dictating";
  }
  if (/write|edit|code|patch|撰写|写入|编辑|编码|修改代码/.test(haystack)) {
    return "writing";
  }
  if (/receive|incoming|inbox|接收|收取|收件/.test(haystack)) {
    return "receiving";
  }
  if (/send|message|mail|slack|teams|发送|消息|邮件/.test(haystack)) {
    return "sending";
  }
  if (/drag|drop|拖拽|拖动/.test(haystack)) {
    return "dragging";
  }
  if (/spawn|create|initialize|start up|创建|初始化|启动/.test(haystack)) {
    return "spawning";
  }
  if (/progress|percent|进度|百分比/.test(haystack)) {
    return "progress";
  }
  if (/radar|discover|scan|扫描|探测|发现/.test(haystack)) {
    return "radar";
  }
  if (/search|browse|web|research|检索|搜索|浏览|查找|读取网页/.test(haystack)) {
    return "searching";
  }
  if (/wait|await|pending|queue|等待|排队/.test(haystack)) {
    return "orbit";
  }
  if (/think|reason|plan|analysis|思考|推理|规划|分析/.test(haystack)) {
    return "thinking";
  }
  return "working";
}
