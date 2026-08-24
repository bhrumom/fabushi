import {
  forwardRef,
  useMemo,
  type CSSProperties,
  type ReactNode,
} from "react";
import {
  FabushiBotMarkEngine,
  fabushiAccentForState,
  fabushiRhythmForBot,
} from "./fabushi-bot-mark-engine";
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
  | "leaf"
  | "jelly";

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
  "blob", "pebble", "bean", "egg", "squircle", "capsule", "cloud", "teardrop", "leaf", "jelly",
];

const COLORS: readonly BotMarkColor[] = [
  "brown", "red", "orange", "yellow", "green", "cyan", "blue", "violet", "magenta", "gray",
];

const AMBIENT_MOTION_STATES = new Set<BotMarkState>([
  "idle", "sleeping", "drowsy", "bored", "powering-down",
]);

export function botMarkMotionTier(
  state: BotMarkState,
  emphasis = false,
  followPointer = false,
): "ambient" | "active" {
  return !emphasis && !followPointer && AMBIENT_MOTION_STATES.has(state) ? "ambient" : "active";
}

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

const SHAPE_PATHS: Record<BotMarkShape, string> = {
  blob: "M50 9C68 8 88 20 91 39C95 59 85 82 65 90C43 99 18 88 10 67C3 48 10 25 28 15C35 11 42 9 50 9Z",
  pebble: "M31 11H69C82 11 91 23 91 37V63C91 78 80 90 65 92H35C20 91 9 79 9 64V36C9 23 18 13 31 11Z",
  bean: "M22 18C33 7 51 8 64 16C80 25 91 41 90 58C89 76 75 90 57 92C39 94 22 85 13 70C2 52 7 33 22 18Z",
  egg: "M50 7C67 7 82 24 88 43C95 66 82 91 55 94C29 97 10 80 12 56C13 35 30 8 50 7Z",
  squircle: "M29 9H71C84 9 91 16 91 29V71C91 84 84 91 71 91H29C16 91 9 84 9 71V29C9 16 16 9 29 9Z",
  tablet: "M24 12H76C85 12 91 20 91 29V71C91 81 84 88 74 88H26C16 88 9 81 9 71V29C9 20 15 12 24 12Z",
  capsule: "M28 15H72C86 15 94 27 94 42V58C94 73 85 85 70 85H30C15 85 6 73 6 58V42C6 27 14 15 28 15Z",
  cylinder: "M22 19C22 11 78 11 78 19V81C78 89 22 89 22 81V19Z",
  hex: "M27 10H73L94 50L73 90H27L6 50L27 10Z",
  gem: "M50 5L88 28L82 72L50 95L18 72L12 28L50 5Z",
  crystal: "M50 4L82 20L94 55L70 93H30L6 55L18 20L50 4Z",
  wedge: "M16 18L91 32L78 88L10 72L16 18Z",
  shield: "M50 6L88 18V49C88 73 73 88 50 95C27 88 12 73 12 49V18L50 6Z",
  dome: "M11 55C11 31 28 11 50 11C72 11 89 31 89 55V89H11V55Z",
  arch: "M13 91V48C13 25 29 9 50 9C71 9 87 25 87 48V91H67V49C67 38 60 30 50 30C40 30 33 38 33 49V91H13Z",
  cloud: "M21 80C9 80 4 67 9 57C12 50 18 47 25 47C24 31 35 19 49 19C61 19 71 27 74 39C88 39 96 50 94 63C93 73 85 80 75 80H21Z",
  teardrop: "M50 5C50 5 88 47 88 66C88 84 72 95 50 95C28 95 12 84 12 66C12 47 50 5 50 5Z",
  leaf: "M91 9C63 10 26 17 13 42C1 66 18 89 42 91C70 93 89 62 91 9Z",
  jelly: "M12 56C12 29 29 10 50 10C71 10 88 29 88 56V64C88 73 83 79 76 80C70 81 66 77 62 71C59 78 55 83 49 83C43 83 39 78 36 71C32 77 27 81 21 79C15 77 12 71 12 63V56Z",
};

const SHAPE_SCALE: Record<BotMarkShape, number> = {
  blob: 0.94, pebble: 0.97, bean: 0.98, egg: 0.96, squircle: 0.9, tablet: 1,
  capsule: 0.98, cylinder: 0.96, hex: 0.93, gem: 0.94, crystal: 0.92, wedge: 0.94,
  shield: 0.95, dome: 0.95, arch: 0.95, cloud: 0.96, teardrop: 0.94, leaf: 0.94, jelly: 0.98,
};

const DEFAULT_POSE: BotMarkPose = { turn: 10, tilt: -6, roll: 4, scale: 1 };
const DEFAULT_HOME_POSE: BotMarkPose = { turn: 16, tilt: -8, roll: 6, scale: 1 };
const DEFAULT_FACE_TUNE: BotMarkFaceTune = { size: 0.9, gap: 1.12, height: 1, eyeWidth: 0.98, eyeHeight: 0.94 };

function hashIdentity(value: string): number {
  let hash = 0x811c9dc5;
  for (const char of value) {
    hash ^= char.codePointAt(0) ?? 0;
    hash = Math.imul(hash, 0x01000193);
    hash ^= hash >>> 13;
  }
  return hash >>> 0;
}

export function botMarkShape(botId: string): BotMarkShape {
  return IDENTITY_SHAPES[hashIdentity(`shape:${botId}`) % IDENTITY_SHAPES.length] ?? "blob";
}

export function botMarkShapeIndex(botId: string): number {
  return hashIdentity(`shape:${botId}`) % IDENTITY_SHAPES.length;
}

export function botMarkColorId(botId: string): BotMarkColor {
  return COLORS[hashIdentity(`color:${botId}`) % COLORS.length] ?? "brown";
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
  const shape = shapeOverride ?? botMarkShape(botId);
  const color = colorOverride ?? botMarkColorId(botId);
  const colorValue = COLOR_VALUES[color];
  const rhythm = useMemo(() => fabushiRhythmForBot(botId), [botId]);
  const accent = fabushiAccentForState(state);
  const shapeScale = SHAPE_SCALE[shape];
  const effectiveEyeScale = eyeScale * Math.max(0.9, Math.min(1.08, 0.95 / shapeScale));
  const style = {
    width: size,
    height: size,
    "--bot-mark-size": `${size}px`,
    "--fg": `light-dark(${colorValue.light}, ${colorValue.dark})`,
    "--bg": eyeColor ?? "var(--bot-mark-eye-color, var(--app, #0b0b0b))",
    "--bot-mark-breathe-duration": `${rhythm.breatheMs}ms`,
    "--bot-mark-orbit-duration": `${rhythm.orbitMs}ms`,
    "--bot-mark-pulse-duration": `${rhythm.pulseMs}ms`,
    "--bot-mark-motion-delay": `${rhythm.delayMs}ms`,
  } as CSSProperties;

  return (
    <span
      className={`${styles.botMark} ${className}`.trim()}
      data-bot-id={botId}
      data-agent-state={state}
      data-paused={paused || undefined}
      data-shape={shape}
      data-color={color}
      data-accent={accent}
      data-motion-tier={botMarkMotionTier(state, emphasis, followPointer)}
      data-engine="fabushi-motion-v2"
      style={style}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      role={label ? "img" : undefined}
    >
      <span className={styles.botMarkAura} aria-hidden="true" />
      <span className={styles.botMarkAuraSecondary} aria-hidden="true" />
      <span className={styles.botMarkParticles} aria-hidden="true"><i /><i /><i /></span>
      <FabushiBotMarkEngine
        ref={ref}
        botId={botId}
        state={state}
        size={size}
        shapePath={SHAPE_PATHS[shape]}
        shapeScale={shapeScale}
        gazeTarget={gazeTarget}
        followPointer={followPointer}
        emphasis={emphasis}
        spinSignal={spinSignal}
        badgeColor={badgeColor}
        paused={paused}
        pose={{ ...DEFAULT_POSE, ...pose }}
        poseHome={{ ...DEFAULT_HOME_POSE, ...poseHome }}
        faceTune={{ ...DEFAULT_FACE_TUNE, ...faceTune }}
        eyeScale={effectiveEyeScale}
        uniformEyes={uniformEyes}
        eyeTopology={eyeTopology}
        inkGradient={inkGradient}
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
