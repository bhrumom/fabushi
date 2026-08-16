import {
  forwardRef,
  useCallback,
  useEffect,
  useId,
  useImperativeHandle,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
} from "react";
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
};

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

function gazeVectorForRect(rect: DOMRect, point: GazePoint): GazePoint {
  const halfWidth = Math.max(rect.width / 2, 1);
  const halfHeight = Math.max(rect.height / 2, 1);
  return {
    x: Math.max(-1, Math.min(1, (point.x - (rect.left + halfWidth)) / halfWidth)),
    y: Math.max(-1, Math.min(1, (point.y - (rect.top + halfHeight)) / halfHeight)),
  };
}

function eyeExpression(state: BotMarkState): { width: number; height: number; y: number; tilt: number } {
  if (["sleeping", "powering-down"].includes(state)) return { width: 8, height: 1.5, y: 50, tilt: 0 };
  if (["drowsy", "bored", "suspicious"].includes(state)) return { width: 8, height: 3, y: 49, tilt: state === "suspicious" ? -7 : 0 };
  if (["surprised", "scared", "waking"].includes(state)) return { width: 7.5, height: 10, y: 48, tilt: 0 };
  if (["happy", "laughing", "celebrate", "proud"].includes(state)) return { width: 8, height: 4.5, y: 47, tilt: 0 };
  if (["angry", "alerting"].includes(state)) return { width: 8, height: 4, y: 48, tilt: -12 };
  if (["sad", "shy"].includes(state)) return { width: 7.5, height: 5, y: 50, tilt: 7 };
  return { width: 7.5, height: 7, y: 48, tilt: 0 };
}

function motionForState(state: BotMarkState, phase: boolean): { rotate: number; x: number; y: number; scale: number } {
  const direction = phase ? 1 : -1;
  if (["alerting", "angry", "confused"].includes(state)) return { rotate: direction * 4, x: direction * 1.8, y: 0, scale: 1 };
  if (["celebrate", "excited", "bouncing", "playful"].includes(state)) return { rotate: direction * 3, x: 0, y: phase ? -3 : 1, scale: phase ? 1.06 : 0.98 };
  if (["radar", "orbit", "loading", "progress", "searching"].includes(state)) return { rotate: direction * 5, x: direction, y: -direction, scale: 1 };
  if (["writing", "sending", "receiving", "uploading", "working"].includes(state)) return { rotate: direction * 1.5, x: direction * 1.2, y: 0, scale: 1 };
  if (["humming", "listening", "dictating"].includes(state)) return { rotate: 0, x: 0, y: direction, scale: phase ? 1.02 : 0.99 };
  return { rotate: direction * 0.7, x: 0, y: phase ? -0.5 : 0.5, scale: 1 };
}

function stateAccent(state: BotMarkState): "none" | "orbit" | "pulse" | "alert" {
  if (["orbit", "radar", "searching", "loading", "progress"].includes(state)) return "orbit";
  if (["thinking", "working", "writing", "sending", "receiving", "uploading", "spawning"].includes(state)) return "pulse";
  if (["alerting", "angry", "scared"].includes(state)) return "alert";
  return "none";
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
  const wrapperRef = useRef<HTMLSpanElement | null>(null);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const gradientId = useId().replace(/:/g, "");
  const [gaze, setGaze] = useState<GazePoint>({ x: 0, y: 0 });
  const [phase, setPhase] = useState(false);
  const [spinDegrees, setSpinDegrees] = useState(0);
  const [impulse, setImpulse] = useState<"none" | "bounce" | "burst">("none");
  const shape = shapeOverride ?? botMarkShape(botId);
  const color = colorOverride ?? botMarkColorId(botId);
  const colorValue = COLOR_VALUES[color];

  const triggerImpulse = useCallback((kind: "bounce" | "burst") => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    setImpulse(kind);
    resetTimer.current = setTimeout(() => setImpulse("none"), 260);
  }, []);

  useImperativeHandle(ref, () => ({
    spin(turns = 1) {
      setSpinDegrees((degrees) => degrees + Math.max(-4, Math.min(4, turns)) * 360);
    },
    bounce() {
      triggerImpulse("bounce");
    },
    burst() {
      triggerImpulse("burst");
    },
  }), [triggerImpulse]);

  useEffect(() => () => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
  }, []);

  useEffect(() => {
    if (spinSignal) setSpinDegrees((degrees) => degrees + 360);
  }, [spinSignal]);

  useEffect(() => {
    if (paused) return undefined;
    const interval = setInterval(() => setPhase((value) => !value), 620);
    return () => clearInterval(interval);
  }, [paused]);

  const updateGaze = useCallback((point: GazePoint | null) => {
    const element = wrapperRef.current;
    if (!element || !point) {
      setGaze({ x: 0, y: 0 });
      return;
    }
    const rect = element.getBoundingClientRect();
    if (rect.width > 0 && rect.height > 0) setGaze(gazeVectorForRect(rect, point));
  }, []);

  useEffect(() => {
    if (!followPointer) updateGaze(gazeTarget);
  }, [followPointer, gazeTarget, updateGaze]);

  useEffect(() => {
    if (!followPointer) return undefined;
    const onPointerMove = (event: PointerEvent) => updateGaze({ x: event.clientX, y: event.clientY });
    const onPointerLeave = () => setGaze({ x: 0, y: 0 });
    window.addEventListener("pointermove", onPointerMove, { passive: true });
    document.documentElement.addEventListener("pointerleave", onPointerLeave);
    return () => {
      window.removeEventListener("pointermove", onPointerMove);
      document.documentElement.removeEventListener("pointerleave", onPointerLeave);
    };
  }, [followPointer, updateGaze]);

  const expression = eyeExpression(state);
  const motion = paused ? { rotate: 0, x: 0, y: 0, scale: 1 } : motionForState(state, phase);
  const accent = stateAccent(state);
  const homePose = state === "idle" || state === "sleeping" ? poseHome : pose;
  const faceScale = Math.max(0.7, Math.min(1.35, (faceTune?.size ?? 1) * eyeScale));
  const eyeGap = 16 * (faceTune?.gap ?? 1);
  const eyeWidth = expression.width * (faceTune?.eyeWidth ?? 1) * faceScale;
  const eyeHeight = expression.height * (faceTune?.eyeHeight ?? 1) * (faceTune?.height ?? 1) * faceScale;
  const eyeY = expression.y + gaze.y * 2.4;
  const leftX = 50 - eyeGap / 2 + gaze.x * 2.8;
  const rightX = 50 + eyeGap / 2 + gaze.x * 2.8;
  const impulseScale = impulse === "burst" ? 1.12 : impulse === "bounce" ? 1.06 : 1;
  const impulseY = impulse === "bounce" ? -4 : 0;
  const rotation = (homePose?.roll ?? 0) * 0.08 + motion.rotate + spinDegrees;
  const baseScale = Math.max(0.82, Math.min(1.14, homePose?.scale ?? 1));
  const fill = inkGradient ? `url(#${gradientId})` : "var(--fg)";
  const style = {
    width: size,
    height: size,
    "--bot-mark-size": `${size}px`,
    "--fg": `light-dark(${colorValue.light}, ${colorValue.dark})`,
    "--bg": eyeColor ?? "var(--bot-mark-eye-color, var(--app, #0b0b0b))",
  } as CSSProperties;

  const transform = useMemo(
    () => `translate(${motion.x} ${motion.y + impulseY}) rotate(${rotation} 50 50) scale(${baseScale * motion.scale * impulseScale})`,
    [baseScale, impulseScale, impulseY, motion, rotation],
  );

  return (
    <span
      ref={wrapperRef}
      className={`${styles.botMark} ${className}`.trim()}
      data-bot-id={botId}
      data-agent-state={state}
      data-paused={paused || undefined}
      data-shape={shape}
      data-color={color}
      style={style}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      role={label ? "img" : undefined}
    >
      <svg viewBox="0 0 100 100" focusable="false" aria-hidden="true">
        <defs>
          {inkGradient ? (
            <linearGradient id={gradientId} x1="0" y1="0" x2="1" y2="1" gradientTransform={`rotate(${inkGradient.angle ?? 45} .5 .5)`}>
              <stop offset={`${inkGradient.fromPos ?? 0}%`} stopColor={inkGradient.from} />
              <stop offset={`${inkGradient.toPos ?? 100}%`} stopColor={inkGradient.to} />
            </linearGradient>
          ) : null}
        </defs>
        {emphasis || accent !== "none" ? (
          <circle
            cx="50"
            cy="50"
            r={accent === "orbit" ? (phase ? 46 : 42) : 43}
            fill="none"
            stroke="var(--fg)"
            strokeWidth={accent === "alert" ? 3 : 1.5}
            opacity={accent === "alert" ? (phase ? 0.75 : 0.25) : (phase ? 0.38 : 0.16)}
            strokeDasharray={accent === "orbit" ? "7 6" : undefined}
          />
        ) : null}
        <g style={{ transition: "transform 240ms cubic-bezier(.2,.8,.2,1)" }} transform={transform}>
          <path d={SHAPE_PATHS[shape]} fill={fill} />
          {eyeTopology ? (
            <path
              d={`M${leftX + eyeWidth / 2 + 2} ${eyeY} Q50 ${eyeY + (state === "curious" ? -3 : 1)} ${rightX - eyeWidth / 2 - 2} ${eyeY}`}
              fill="none"
              stroke="var(--bg)"
              strokeWidth="1.2"
              opacity="0.12"
            />
          ) : null}
          <g fill="var(--bg)" transform={`rotate(${expression.tilt} 50 ${eyeY})`}>
            <ellipse cx={leftX} cy={eyeY} rx={eyeWidth / 2} ry={eyeHeight / 2} />
            <ellipse
              cx={rightX}
              cy={eyeY + (uniformEyes ? 0 : 1.2)}
              rx={(eyeWidth * (uniformEyes ? 1 : 0.92)) / 2}
              ry={(eyeHeight * (uniformEyes ? 1 : 1.08)) / 2}
            />
          </g>
          {state === "curious" ? <circle cx="50" cy="68" r="2.2" fill="var(--bg)" opacity="0.65" /> : null}
          {state === "happy" || state === "laughing" ? <path d="M39 65Q50 73 61 65" fill="none" stroke="var(--bg)" strokeWidth="2.4" strokeLinecap="round" /> : null}
        </g>
        {badgeColor ? <circle cx="82" cy="80" r="7" fill={badgeColor} stroke="var(--bg)" strokeWidth="2" /> : null}
      </svg>
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
