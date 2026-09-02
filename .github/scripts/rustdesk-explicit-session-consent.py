from pathlib import Path

peer = Path('frontend/apps/web/src/lib/remote-computer/desktop-peer.ts')
text = peer.read_text()

text = text.replace(
'''  sessions: RemoteComputerSession[];
  activeSessionId?: string;
''',
'''  sessions: RemoteComputerSession[];
  pendingAuthorization?: RemoteComputerSession;
  activeSessionId?: string;
''',
1,
)
text = text.replace(
'''  private peers = new Map<string, PeerSession>();
  private stopped = true;
''',
'''  private peers = new Map<string, PeerSession>();
  private lastIceServers: RTCIceServer[] = [];
  private stopped = true;
''',
1,
)
text = text.replace(
'''      sessions: [],
      activeSessionId: undefined,
''',
'''      sessions: [],
      pendingAuthorization: undefined,
      activeSessionId: undefined,
''',
1,
)
# There are two teardown state blocks; ensure both clear pending authorization.
text = text.replace(
'''      sessions: [],
      activeSessionId: undefined,
      activeClientId: undefined,
      connectionState: "idle",
      channelOpen: false,
    });
  }

  private syncSessionTimer''',
'''      sessions: [],
      pendingAuthorization: undefined,
      activeSessionId: undefined,
      activeClientId: undefined,
      connectionState: "idle",
      channelOpen: false,
    });
  }

  private syncSessionTimer''',
1,
)
text = text.replace(
'''      running: false,
      activeSessionId: undefined,
''',
'''      running: false,
      pendingAuthorization: undefined,
      activeSessionId: undefined,
''',
1,
)
old_poll = '''      const { sessions, iceServers } = normalizeSessionsPayload(event.data, this.deviceId);
      this.update({ sessions, error: undefined });
      const known = new Set(sessions.map((session) => session.sessionId));
      for (const peer of [...this.peers.values()]) {
        if (!known.has(peer.session.sessionId)) await this.closePeer(peer, false);
      }
      if (![...this.peers.values()].some((peer) => !peer.closing)) {
        const pending = sessions.find((session) => session.state === "pending");
        if (pending) await this.openPeer(pending, iceServers);
      }
'''
new_poll = '''      const { sessions, iceServers } = normalizeSessionsPayload(event.data, this.deviceId);
      this.lastIceServers = iceServers;
      const known = new Set(sessions.map((session) => session.sessionId));
      for (const peer of [...this.peers.values()]) {
        if (!known.has(peer.session.sessionId)) await this.closePeer(peer, false);
      }
      const hasActivePeer = [...this.peers.values()].some((peer) => !peer.closing);
      const pending = hasActivePeer ? undefined : sessions.find((session) => session.state === "pending");
      this.update({
        sessions,
        pendingAuthorization: pending,
        error: undefined,
      });
'''
assert old_poll in text, 'pollSessions automatic acceptance block changed'
text = text.replace(old_poll, new_poll, 1)

insert_before = '''  private async openPeer(session: RemoteComputerSession, iceServers: RTCIceServer[]): Promise<void> {
'''
consent_methods = '''  async approvePendingSession(sessionId: string): Promise<void> {
    if (this.stopped || !this.controlEnabled) throw new Error("Remote control is disabled");
    const pending = this.state.sessions.find((session) => session.sessionId === sessionId && session.state === "pending");
    if (!pending || this.state.pendingAuthorization?.sessionId !== sessionId) {
      throw new Error("Remote session is no longer awaiting authorization");
    }
    this.update({ pendingAuthorization: undefined, error: undefined });
    try {
      await this.openPeer(pending, this.lastIceServers);
    } catch (cause) {
      this.update({ error: cause instanceof Error ? cause.message : String(cause) });
      throw cause;
    }
  }

  async denyPendingSession(sessionId: string): Promise<void> {
    const pending = this.state.sessions.find((session) => session.sessionId === sessionId && session.state === "pending");
    if (!pending) return;
    await remoteRequest(this.transport, {
      type: "remoteComputer.sessionClose",
      requestId: requestId("remote-deny"),
      deviceId: this.deviceId,
      sessionId,
    });
    this.update({
      sessions: this.state.sessions.filter((session) => session.sessionId !== sessionId),
      pendingAuthorization: undefined,
      error: undefined,
    });
  }

'''
assert insert_before in text, 'openPeer marker changed'
text = text.replace(insert_before, consent_methods + insert_before, 1)
peer.write_text(text)

shell = Path('desktop/src/messaging-shell-v2.tsx')
text = shell.read_text()
pairing = '''            {hostSettings.remoteControlEnabled && remoteComputerState?.registration?.pairingCode ? <div className={styles.computerPairingCode}>
              <span><small>配对码</small><strong>{remoteComputerState.registration.pairingCode}</strong></span>
              <button type="button" onClick={() => void remoteComputerControllerRef.current?.refreshPairingCode().catch((cause: unknown) => setError(cause instanceof Error ? cause.message : String(cause)))}>刷新</button>
            </div> : null}
            {remoteComputerState?.activeSessionId ? <button type="button" className={styles.computerDangerButton} onClick={() => void remoteComputerControllerRef.current?.disconnectActive()}>断开当前远控</button> : null}
'''
replacement = '''            {hostSettings.remoteControlEnabled && remoteComputerState?.registration?.pairingCode ? <div className={styles.computerPairingCode}>
              <span><small>配对码</small><strong>{remoteComputerState.registration.pairingCode}</strong></span>
              <button type="button" onClick={() => void remoteComputerControllerRef.current?.refreshPairingCode().catch((cause: unknown) => setError(cause instanceof Error ? cause.message : String(cause)))}>刷新</button>
            </div> : null}
            {remoteComputerState?.pendingAuthorization ? <div className={styles.computerPairingCode} data-testid="remote-session-consent">
              <span><small>远控请求</small><strong>{remoteComputerState.pendingAuthorization.clientLabel || '已配对设备'}</strong></span>
              <button type="button" onClick={() => void remoteComputerControllerRef.current?.approvePendingSession(remoteComputerState.pendingAuthorization!.sessionId).catch((cause: unknown) => setError(cause instanceof Error ? cause.message : String(cause)))}>允许本次连接</button>
              <button type="button" className={styles.computerDangerButton} onClick={() => void remoteComputerControllerRef.current?.denyPendingSession(remoteComputerState.pendingAuthorization!.sessionId).catch((cause: unknown) => setError(cause instanceof Error ? cause.message : String(cause)))}>拒绝</button>
            </div> : null}
            {remoteComputerState?.activeSessionId ? <button type="button" className={styles.computerDangerButton} onClick={() => void remoteComputerControllerRef.current?.disconnectActive()}>断开当前远控</button> : null}
'''
assert pairing in text, 'remote settings consent insertion marker changed'
text = text.replace(pairing, replacement, 1)
shell.write_text(text)
