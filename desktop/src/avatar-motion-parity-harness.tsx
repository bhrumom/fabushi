import { useLayoutEffect, useRef, useState } from 'react';

import { FabushiBotMarkEngine } from '../../frontend/apps/web/src/app/host/fabushi-bot-mark-engine';
import type { BotMarkHandle, BotMarkState } from '../../frontend/apps/web/src/app/host/bot-mark';

type GazePoint = { x: number; y: number };

type ParityControl = {
  configure(input: { identity: string; state: BotMarkState; followPointer?: boolean }): number;
  setState(state: BotMarkState): void;
  setGaze(gaze: GazePoint | null): void;
  setFollowPointer(value: boolean): void;
  spin(turns?: number): void;
  bounce(): void;
  burst(): void;
  snapshot(): Record<string, string | number | null>;
};

type ParityWindow = Window & typeof globalThis & {
  __FABUSHI_AVATAR_PARITY_CAPTURE__?: boolean;
  __fabushiAvatarParity?: ParityControl;
};

function parityWindow(): ParityWindow {
  return window as ParityWindow;
}

export default function AvatarMotionParityHarness() {
  const handleRef = useRef<BotMarkHandle>(null);
  const generationRef = useRef(0);
  const [generation, setGeneration] = useState(0);
  const [identity, setIdentity] = useState('gbf509-idle-2');
  const [state, setState] = useState<BotMarkState>('idle');
  const [gaze, setGaze] = useState<GazePoint | null>(null);
  const [followPointer, setFollowPointer] = useState(false);

  useLayoutEffect(() => {
    const host = parityWindow();
    host.__FABUSHI_AVATAR_PARITY_CAPTURE__ = true;
    host.__fabushiAvatarParity = {
      configure(input) {
        generationRef.current += 1;
        setIdentity(input.identity);
        setState(input.state);
        setGaze(null);
        setFollowPointer(Boolean(input.followPointer));
        setGeneration(generationRef.current);
        return generationRef.current;
      },
      setState(nextState) {
        setState(nextState);
      },
      setGaze(nextGaze) {
        setGaze(nextGaze);
      },
      setFollowPointer(value) {
        setFollowPointer(value);
      },
      spin(turns = 1) {
        handleRef.current?.spin(turns);
      },
      bounce() {
        handleRef.current?.bounce();
      },
      burst() {
        handleRef.current?.burst();
      },
      snapshot() {
        const svg = document.querySelector<SVGSVGElement>('svg[data-fabushi-avatar-runtime]');
        if (!svg) return { ready: 0 };
        const d = svg.dataset;
        return {
          ready: 1,
          state: d.state ?? null,
          bodyY: Number(d.motionBodyY ?? 'NaN'),
          roll: Number(d.motionRoll ?? 'NaN'),
          spin: Number(d.motionSpin ?? 'NaN'),
          rotation: Number(d.motionRotation ?? 'NaN'),
          squash: Number(d.motionSquash ?? 'NaN'),
          gazeX: Number(d.motionGazeX ?? 'NaN'),
          gazeY: Number(d.motionGazeY ?? 'NaN'),
          leftEyeOpen: Number(d.motionLeftEyeOpen ?? 'NaN'),
          rightEyeOpen: Number(d.motionRightEyeOpen ?? 'NaN'),
          burst: Number(d.motionBurst ?? 'NaN'),
        };
      },
    };
    return () => {
      delete host.__fabushiAvatarParity;
      delete host.__FABUSHI_AVATAR_PARITY_CAPTURE__;
    };
  }, []);

  return (
    <main
      data-testid="avatar-motion-parity-harness"
      data-generation={generation}
      style={{
        position: 'fixed',
        inset: 0,
        width: 640,
        height: 480,
        display: 'grid',
        placeItems: 'center',
        overflow: 'hidden',
        background: '#f3efe6',
      }}
    >
      <div
        data-testid="avatar-motion-parity-stage"
        style={{
          width: 64,
          height: 64,
          display: 'grid',
          placeItems: 'center',
        }}
      >
        <FabushiBotMarkEngine
          key={generation}
          ref={handleRef}
          botId={identity}
          state={state}
          size={64}
          shape="blob"
          color="black"
          gazeTarget={gaze}
          followPointer={followPointer}
          emphasis={false}
          paused={false}
          eyeColor="#f3efe6"
        />
      </div>
    </main>
  );
}
