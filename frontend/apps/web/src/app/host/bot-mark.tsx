import {
  forwardRef,
  type CSSProperties,
  type ReactNode,
} from "react";
import { FabushiBotMarkEngine } from "./fabushi-bot-mark-engine";
import styles from "./host.module.css";

export type BotMarkState =
  | "sleeping"
  | "waking"
  | "idle"
  | "listening"
  | "thinking"
  | "searching"
  | "working"
  | "tool-running"
  | "speaking"
  | "result"
  | "error"
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
  | "squircle"
  | "tablet"
  | "wedge"
  | "hex"
  | "cloud"
  | "teardrop";

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
};

const IDENTITY_SHAPES: readonly BotMarkShape[] = [
  "blob", "pebble", "squircle", "tablet", "wedge", "hex", "cloud", "teardrop",
];

const COLORS: readonly BotMarkColor[] = [
  "brown", "red", "orange", "yellow", "green", "cyan", "blue", "violet", "magenta", "gray",
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

function hashIdentity(value: string): number {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash = Math.imul(hash ^ value.charCodeAt(index), 16777619);
  }
  return hash >>> 0;
}

function identityRandom(seed: number): () => number {
  let value = seed >>> 0;
  return () => {
    value = value + 1831565813 | 0;
    let next = Math.imul(value ^ value >>> 15, 1 | value);
    next = next + Math.imul(next ^ next >>> 7, 61 | next) ^ next;
    return ((next ^ next >>> 14) >>> 0) / 4294967296;
  };
}

function shapeHash(value: string): number {
  let hash = hashIdentity(value);
  hash = Math.imul(hash ^ hash >>> 16, 73244475);
  hash = Math.imul(hash ^ hash >>> 13, 3266489909);
  return (hash ^ hash >>> 16) >>> 0;
}

export function botMarkShape(botId: string): BotMarkShape {
  return IDENTITY_SHAPES[shapeHash(botId) % IDENTITY_SHAPES.length] ?? "blob";
}

export function botMarkShapeIndex(botId: string): number {
  return shapeHash(botId) % IDENTITY_SHAPES.length;
}

export function botMarkColorId(botId: string): BotMarkColor {
  const seed = (hashIdentity(botId) ^ Math.imul(1, 2654435769)) >>> 0;
  const index = Math.floor(identityRandom((seed ^ 2654435769) >>> 0)() * COLORS.length);
  return COLORS[index] ?? "gray";
}

export function botMarkColor(botId: string): string {
  const value = COLOR_VALUES[botMarkColorId(botId)];
  return `light-dark(${value.light}, ${value.dark})`;
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
  },
  ref,
) {
  const shape = shapeOverride ?? botMarkShape(botId);
  const color = colorOverride ?? botMarkColorId(botId);
  const style = {
    width: size,
    height: size,
    "--bot-mark-size": `${size}px`,
    "--bot-mark-eye-color": eyeColor ?? "var(--app, #fff)",
  } as CSSProperties;

  return (
    <span
      className={`${styles.botMark} ${className}`.trim()}
      data-bot-id={botId}
      data-agent-state={state}
      data-paused={paused || undefined}
      data-shape={shape}
      data-color={color}
      data-engine="fabushi-motion-v2"
      data-renderer="grok-mark"
      style={style}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      role={label ? "img" : undefined}
    >
      <FabushiBotMarkEngine
        ref={ref}
        botId={botId}
        state={state}
        size={size}
        shape={shape}
        color={color}
        gazeTarget={gazeTarget}
        followPointer={followPointer}
        emphasis={emphasis}
        spinSignal={spinSignal}
        badgeColor={badgeColor}
        paused={paused}
        eyeColor={eyeColor}
      />
      {children}
    </span>
  );
});

export function botMarkStateFromActivity(
  activity: { kind?: string; title?: string; detail?: string } | undefined,
): BotMarkState {
  if (!activity) return "thinking";
  const text = `${activity.kind ?? ""} ${activity.title ?? ""} ${activity.detail ?? ""}`.toLocaleLowerCase();
  const rules: Array<[RegExp, BotMarkState]> = [
    [/alert|warn|error|approval|permission|警告|错误|报错|审批|授权/u, "alerting"],
    [/notify|notification|remind|通知|提醒/u, "notifying"],
    [/upload|上传/u, "uploading"],
    [/download|load|fetch|生成图片|下载|加载|获取文件/u, "loading"],
    [/dictat|speech|voice|audio|听写|语音|录音/u, "dictating"],
    [/write|edit|code|patch|撰写|写入|编辑|编码|修改代码/u, "writing"],
    [/receive|incoming|inbox|接收|收取|收件/u, "receiving"],
    [/send|message|mail|slack|teams|发送|消息|邮件/u, "sending"],
    [/drag|drop|拖拽|拖动/u, "dragging"],
    [/spawn|create|initialize|start up|创建|初始化|启动/u, "spawning"],
    [/progress|percent|进度|百分比/u, "progress"],
    [/radar|discover|scan|扫描|探测|发现/u, "radar"],
    [/search|browse|web|research|检索|搜索|浏览|查找|读取网页/u, "searching"],
    [/wait|await|pending|queue|等待|排队/u, "orbit"],
    [/think|reason|plan|analysis|思考|推理|规划|分析/u, "thinking"],
  ];
  return rules.find(([pattern]) => pattern.test(text))?.[1] ?? "working";
}
