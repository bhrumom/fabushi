import { forwardRef, useEffect, useImperativeHandle, useRef } from "react";

import type { BotMarkColor, BotMarkHandle, BotMarkShape, BotMarkState } from "./bot-mark";
import {
  CursorAvatar,
  DEFAULT_SILHOUETTE,
  type CursorAvatarHandle,
  type CursorSilhouette,
  type CursorState,
} from "./openmaus-cursor-avatar";

/**
 * OpenMausBot avatar integration.
 *
 * Upstream: milind-soni/OpenMausBot@667af71ae7e93640ba4b1a5f3b38a1ad342025da
 * File: src/components/CursorAvatar.tsx (Apache-2.0)
 *
 * Fabushi keeps its BotMark public API so every existing product surface can
 * share the exact same mascot engine without creating a second identity stack.
 */

type GazePoint = { x: number; y: number };

export type FabushiBotMarkEngineProps = {
  botId: string;
  state: BotMarkState;
  size: number;
  shape: BotMarkShape;
  color: BotMarkColor;
  gazeTarget?: GazePoint | null;
  followPointer?: boolean;
  emphasis?: boolean;
  spinSignal?: number;
  badgeColor?: string;
  paused?: boolean;
  eyeColor?: string;
};

const COLOR_VALUES: Record<BotMarkColor, string> = {
  black: "#151515",
  brown: "#A27952",
  red: "#FF3E51",
  orange: "#FF781C",
  yellow: "#FFAF38",
  green: "#00C972",
  cyan: "#1CC3B0",
  blue: "#2A92FE",
  violet: "#A97EFE",
  magenta: "#FF5EB1",
  gray: "#959595",
};

function mix(hex: string, toward: string, amount: number): string {
  const source = Number.parseInt(hex.slice(1), 16);
  const target = Number.parseInt(toward.slice(1), 16);
  const channel = (shift: number) => {
    const left = (source >> shift) & 0xff;
    const right = (target >> shift) & 0xff;
    return Math.round(left + (right - left) * amount);
  };
  return `#${[channel(16), channel(8), channel(0)]
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("")}`;
}

function gradientFor(color: BotMarkColor): [string, string, string] {
  const fill = COLOR_VALUES[color] ?? COLOR_VALUES.gray;
  return [mix(fill, "#ffffff", 0.55), fill, mix(fill, "#000000", 0.42)];
}

// OpenMaus' exported Cursor silhouette bakes black into its source path.
// Its Avatar wrapper replaces that slot with {{GRADIENT}}; do the same here.
const OPENMAUS_SILHOUETTE: CursorSilhouette = {
  ...DEFAULT_SILHOUETTE,
  body: DEFAULT_SILHOUETTE.body.replace(/fill="#000000"/g, 'fill="{{GRADIENT}}"'),
};

function normalizedGaze(value?: GazePoint | null): GazePoint | undefined {
  if (!value) return undefined;
  return {
    x: Math.max(-1, Math.min(1, Number(value.x) || 0)),
    y: Math.max(-1, Math.min(1, Number(value.y) || 0)),
  };
}

export const FabushiBotMarkEngine = forwardRef<BotMarkHandle, FabushiBotMarkEngineProps>(
  function FabushiBotMarkEngine(
    {
      state,
      size,
      color,
      gazeTarget,
      followPointer = false,
      emphasis = false,
      spinSignal = 0,
      paused = false,
      eyeColor,
    },
    ref,
  ) {
    const avatarRef = useRef<CursorAvatarHandle>(null);
    const previousSpinSignal = useRef(spinSignal);

    useImperativeHandle(ref, () => ({
      spin: (turns = 1) => avatarRef.current?.spin(Math.max(260, Math.round(Math.abs(turns) * 520))),
      bounce: () => avatarRef.current?.blink(),
      burst: () => {
        avatarRef.current?.blink();
        avatarRef.current?.spin(520);
      },
    }), []);

    useEffect(() => {
      if (spinSignal === previousSpinSignal.current) return;
      previousSpinSignal.current = spinSignal;
      avatarRef.current?.spin(620);
    }, [spinSignal]);

    return (
      <CursorAvatar
        ref={avatarRef}
        state={state as CursorState}
        size={size}
        silhouette={OPENMAUS_SILHOUETTE}
        gradient={gradientFor(color)}
        eyeColor={eyeColor ?? "#ffffff"}
        gaze={normalizedGaze(gazeTarget)}
        lookAround={followPointer ? 1 : 0}
        motion={emphasis ? 1 : undefined}
        paused={paused}
        effects={!paused}
        glyphs={!paused}
        autoBlink={!paused}
        autoExpression={!paused}
        style={{ display: "block", width: size, height: size }}
      />
    );
  },
);
