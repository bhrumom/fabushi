import fs from 'node:fs';

const file = 'desktop/src/messaging-shell-v2.tsx';
let source = fs.readFileSync(file, 'utf8');

function replaceOnce(label, from, to) {
  const index = source.indexOf(from);
  if (index < 0) throw new Error(`M8-CALL-007 patch anchor missing: ${label}`);
  if (source.indexOf(from, index + from.length) >= 0) throw new Error(`M8-CALL-007 patch anchor is not unique: ${label}`);
  source = `${source.slice(0, index)}${to}${source.slice(index + from.length)}`;
}

replaceOnce('MiniApp call imports', `import {
  installedMiniAppBotProjections,
  miniAppBotResponseText,
  type MiniAppBotCommand,
} from './miniapp-bot-projection';`, `import {
  installedMiniAppBotProjections,
  miniAppBotResponseText,
  type MiniAppBotCallProgram,
  type MiniAppBotCallPrograms,
  type MiniAppBotCommand,
} from './miniapp-bot-projection';
import { MiniAppCallDialog } from './miniapp-call-dialog';`);

replaceOnce('PeerItem calls', `  miniAppId?: string;
  miniAppCommands?: MiniAppBotCommand[];
  miniAppMenuButtonText?: string;
};`, `  miniAppId?: string;
  miniAppCommands?: MiniAppBotCommand[];
  miniAppMenuButtonText?: string;
  miniAppCalls?: MiniAppBotCallPrograms;
};`);

replaceOnce('MiniAppCallSession type', `type LocalCall = {
  kind: 'voice' | 'video';
  title: string;
  status: WebRtcCallStatus;
  incoming: boolean;
  muted: boolean;
  videoEnabled: boolean;
  error?: string;
};`, `type LocalCall = {
  kind: 'voice' | 'video';
  title: string;
  status: WebRtcCallStatus;
  incoming: boolean;
  muted: boolean;
  videoEnabled: boolean;
  error?: string;
};

type MiniAppCallSession = {
  callId: string;
  miniAppId: string;
  title: string;
  kind: 'voice' | 'video';
  program: MiniAppBotCallProgram;
  html?: string;
};`);

replaceOnce('MiniApp call state', `  const [localCall, setLocalCall] = useState<LocalCall | null>(null);
  const [incomingCall, setIncomingCall] = useState<IncomingFabushiCall | null>(null);
  const [miniApp, setMiniApp] = useState<{ id: string; title: string; html: string } | null>(null);`, `  const [localCall, setLocalCall] = useState<LocalCall | null>(null);
  const [incomingCall, setIncomingCall] = useState<IncomingFabushiCall | null>(null);
  const [miniApp, setMiniApp] = useState<{ id: string; title: string; html: string } | null>(null);
  const [miniAppCall, setMiniAppCall] = useState<MiniAppCallSession | null>(null);`);

replaceOnce('Legacy bot projection calls', `        miniAppId: miniAppByBotId.get(bot.id)?.miniAppId,
        miniAppCommands: miniAppByBotId.get(bot.id)?.commands,
        miniAppMenuButtonText: miniAppByBotId.get(bot.id)?.menuButtonText,`, `        miniAppId: miniAppByBotId.get(bot.id)?.miniAppId,
        miniAppCommands: miniAppByBotId.get(bot.id)?.commands,
        miniAppMenuButtonText: miniAppByBotId.get(bot.id)?.menuButtonText,
        miniAppCalls: miniAppByBotId.get(bot.id)?.calls,`);

replaceOnce('Account bot projection calls', `          miniAppId: miniAppSource?.sourceId,
          miniAppCommands: projection?.commands,
          miniAppMenuButtonText: projection?.menuButtonText ?? (miniAppSource ? '打开小程序' : undefined),`, `          miniAppId: miniAppSource?.sourceId,
          miniAppCommands: projection?.commands,
          miniAppMenuButtonText: projection?.menuButtonText ?? (miniAppSource ? '打开小程序' : undefined),
          miniAppCalls: projection?.calls,`);

replaceOnce('Synthetic MiniApp bot projection calls', `        miniAppId: projection.miniAppId,
        miniAppCommands: projection.commands,
        miniAppMenuButtonText: projection.menuButtonText,
      }));`, `        miniAppId: projection.miniAppId,
        miniAppCommands: projection.commands,
        miniAppMenuButtonText: projection.menuButtonText,
        miniAppCalls: projection.calls,
      }));`);

replaceOnce('MiniApp thread media projection', `  async function loadMiniAppBotThread(miniAppId: string): Promise<DisplayMessage[]> {
    const page = await readMiniAppBotMessages(miniAppId, '', 500);
    const thread = (page.messages ?? []).map((message): DisplayMessage => ({
      id: message.messageId,
      role: message.role === 'user' ? 'me' : 'peer',
      text: message.text,
      createdAtMs: Number.isFinite(Date.parse(message.createdAt)) ? Date.parse(message.createdAt) : Date.now(),
      source: 'legacy',
    }));`, `  async function loadMiniAppBotThread(miniAppId: string): Promise<DisplayMessage[]> {
    const page = await readMiniAppBotMessages(miniAppId, '', 500);
    const thread = (page.messages ?? []).map((message): DisplayMessage => {
      const mediaTypeValue = message.payload?.mediaType;
      const mediaType = mediaTypeValue === 'photo' || mediaTypeValue === 'video' || mediaTypeValue === 'document'
        ? mediaTypeValue
        : undefined;
      const mediaValue = message.payload?.media;
      const media = mediaValue && typeof mediaValue === 'object' && !Array.isArray(mediaValue)
        ? mediaValue as unknown as MessagingMediaRef
        : undefined;
      return {
        id: message.messageId,
        role: message.role === 'user' ? 'me' : 'peer',
        text: message.text,
        createdAtMs: Number.isFinite(Date.parse(message.createdAt)) ? Date.parse(message.createdAt) : Date.now(),
        source: 'legacy',
        media,
        mediaType,
      };
    });`);

replaceOnce('MiniApp call execution helpers', `  async function startCall(kind: 'voice' | 'video') {
    if (!activePeer) return;
    if (activePeer.source !== 'selfhosted' || !activePeer.conversationId || !activePeer.actorId) {
      setError('远端通话只对已迁移到 Fabushi 自建协议的一对一联系人开放。');
      return;
    }`, `  async function appendMiniAppCallExchange(miniAppId: string, input: string, visibleText = input): Promise<void> {
    const createdAtMs = Date.now();
    const userMessage: DisplayMessage = {
      id: nextRequestId('miniapp-call-user'),
      source: 'legacy',
      role: 'me',
      text: visibleText,
      createdAtMs,
    };
    const pendingThread = [...(miniAppBotThreadsRef.current[miniAppId] ?? []), userMessage];
    miniAppBotThreadsRef.current = { ...miniAppBotThreadsRef.current, [miniAppId]: pendingThread };
    const active = peersRef.current.find((peer) => peer.key === activePeerKeyRef.current);
    if (active?.miniAppId === miniAppId) setMessages(pendingThread);
    await appendMiniAppBotMessages(miniAppId, [{
      messageId: userMessage.id,
      role: 'user',
      text: userMessage.text,
      createdAt: new Date(userMessage.createdAtMs).toISOString(),
      payload: { source: 'miniapp-call' },
    }]);
    const routed = await invokeNativeDesktop<Record<string, unknown>>('routeMiniAppInput', {
      pluginId: miniAppId,
      input,
    });
    const responseMessage: DisplayMessage = {
      id: nextRequestId('miniapp-call-response'),
      source: 'legacy',
      role: 'peer',
      text: miniAppBotResponseText(routed),
      createdAtMs: Date.now(),
    };
    const completedThread = [...pendingThread, responseMessage];
    miniAppBotThreadsRef.current = { ...miniAppBotThreadsRef.current, [miniAppId]: completedThread };
    if (active?.miniAppId === miniAppId) setMessages(completedThread);
    await appendMiniAppBotMessages(miniAppId, [{
      messageId: responseMessage.id,
      role: 'assistant',
      text: responseMessage.text,
      createdAt: new Date(responseMessage.createdAtMs).toISOString(),
      payload: { source: 'miniapp-call' },
    }]);
  }

  async function runMiniAppCallCommand(session: MiniAppCallSession, command: string, args?: Record<string, unknown>): Promise<void> {
    const suffix = args && Object.keys(args).length ? ` ${JSON.stringify(args)}` : '';
    const input = `/${session.miniAppId}:${command}${suffix}`;
    await appendMiniAppCallExchange(session.miniAppId, input, `通话服务 · /${command}`);
  }

  async function saveMiniAppCallRecording(session: MiniAppCallSession, blob: Blob, mimeType: string): Promise<void> {
    const extension = mimeType.includes('mp4') ? 'mp4' : 'webm';
    const fileName = `teleprompter-${new Date().toISOString().replaceAll(':', '-')}.${extension}`;
    const file = new File([blob], fileName, { type: mimeType || 'video/webm' });
    setAttachmentProgress(`正在保存 ${fileName}…`);
    try {
      const media = await selfHosted.uploadBlob(file, (uploaded, total) => {
        setAttachmentProgress(`正在保存 ${fileName} · ${Math.round((uploaded / Math.max(total, 1)) * 100)}%`);
      });
      const message: DisplayMessage = {
        id: nextRequestId('miniapp-call-video'),
        source: 'legacy',
        role: 'me',
        text: '口播录制视频',
        createdAtMs: Date.now(),
        media,
        mediaType: 'video',
      };
      const thread = [...(miniAppBotThreadsRef.current[session.miniAppId] ?? []), message];
      miniAppBotThreadsRef.current = { ...miniAppBotThreadsRef.current, [session.miniAppId]: thread };
      const active = peersRef.current.find((peer) => peer.key === activePeerKeyRef.current);
      if (active?.miniAppId === session.miniAppId) setMessages(thread);
      await appendMiniAppBotMessages(session.miniAppId, [{
        messageId: message.id,
        role: 'user',
        text: message.text,
        createdAt: new Date(message.createdAtMs).toISOString(),
        payload: {
          source: 'miniapp-call-recording',
          miniAppId: session.miniAppId,
          callId: session.callId,
          mediaType: 'video',
          media,
        },
      }]);
    } finally {
      setAttachmentProgress(null);
    }
  }

  async function startCall(kind: 'voice' | 'video') {
    if (!activePeer) return;
    if (activePeer.miniAppId) {
      const program = activePeer.miniAppCalls?.[kind];
      if (!program) {
        setError(`这个 Mini App 没有声明${kind === 'video' ? '视频' : '语音'}通话程序。`);
        return;
      }
      setError(null);
      try {
        let html: string | undefined;
        if (program.type === 'miniapp-surface') {
          const installed = installedMiniApps[activePeer.miniAppId] ?? await transport.pluginActive(activePeer.miniAppId);
          if (!installed) throw new Error('请先安装这个 Mini App，再使用它自定义的通话界面。');
          const document = await transport.pluginUiDocument(activePeer.miniAppId);
          html = document.html;
        }
        setMiniAppCall({
          callId: `miniapp-call:${crypto.randomUUID()}`,
          miniAppId: activePeer.miniAppId,
          title: activePeer.title,
          kind,
          program,
          html,
        });
      } catch (cause) {
        setError(cause instanceof Error ? cause.message : String(cause));
      }
      return;
    }
    if (activePeer.source !== 'selfhosted' || !activePeer.conversationId || !activePeer.actorId) {
      setError('远端通话只对已迁移到 Fabushi 自建协议的一对一联系人开放。');
      return;
    }`);

replaceOnce('MiniApp call dialog render', `      {localCall ? <CallDialog call={localCall} localVideoRef={localVideoRef} remoteVideoRef={remoteVideoRef} remoteAudioRef={remoteAudioRef} canAccept={Boolean(incomingCall)} onAccept={() => void acceptIncomingCall()} onDecline={() => void declineIncomingCall()} onMute={() => void toggleCallMute()} onVideo={() => void toggleCallVideo()} onShare={() => void shareCallScreen()} onEnd={() => void endCall()} /> : null}
      {miniApp ? <MiniAppDialog app={miniApp} onClose={() => setMiniApp(null)} /> : null}`, `      {localCall ? <CallDialog call={localCall} localVideoRef={localVideoRef} remoteVideoRef={remoteVideoRef} remoteAudioRef={remoteAudioRef} canAccept={Boolean(incomingCall)} onAccept={() => void acceptIncomingCall()} onDecline={() => void declineIncomingCall()} onMute={() => void toggleCallMute()} onVideo={() => void toggleCallVideo()} onShare={() => void shareCallScreen()} onEnd={() => void endCall()} /> : null}
      {miniAppCall ? <MiniAppCallDialog
        callId={miniAppCall.callId}
        miniAppId={miniAppCall.miniAppId}
        title={miniAppCall.title}
        kind={miniAppCall.kind}
        program={miniAppCall.program}
        html={miniAppCall.html}
        onCommand={(command, args) => runMiniAppCallCommand(miniAppCall, command, args)}
        onNaturalLanguage={miniAppCall.program.aiMode === 'optional'
          ? (input) => appendMiniAppCallExchange(miniAppCall.miniAppId, input, `通话语音/自然语言 · ${input}`)
          : undefined}
        onSaveRecording={(blob, mimeType) => saveMiniAppCallRecording(miniAppCall, blob, mimeType)}
        onClose={() => setMiniAppCall(null)}
      /> : null}
      {miniApp ? <MiniAppDialog app={miniApp} onClose={() => setMiniApp(null)} /> : null}`);

fs.writeFileSync(file, source);
console.log('M8-CALL-007 Messenger integration applied');
