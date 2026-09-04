import DesktopShellCore from './messaging-shell-v2-core';
import { GrokChatParityRuntime, prepareGrokChatParityRuntime } from './grok-chat-parity-runtime';

export default function DesktopShellV2() {
  // Run before the original Messenger renders so cached demo bots are removed
  // and chat.send can project the user's turn as soon as the Host accepts it.
  prepareGrokChatParityRuntime();
  return (
    <>
      <DesktopShellCore />
      <GrokChatParityRuntime />
    </>
  );
}
