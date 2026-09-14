import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { installDesktopAccountSessionSync } from './account-session-sync';
import { installDesktopAppAgentSurface } from './app-agent-surface';
import { installBotIdentityAliases } from './agent-identity-aliases';
import CredentialVault from './credential-vault';
import { installDurableAgentState, restoreDurableAgentState } from './durable-agent-state';
import { GrokChatParityRuntime, prepareGrokChatParityRuntime } from './grok-chat-parity-runtime';
import DesktopShellV2 from './messaging-shell-v2';
import MahayanaAgentInlineReport from './mahayana-agent-inline-report';
import { installMiniAppComposerOpenBridge } from './miniapp-composer-open-bridge';
import { installDesktopMiniAppDiscoveryAliases } from './miniapp-discovery-aliases';
import { installDesktopMiniAppWebMcpHost } from './miniapp-webmcp-host';
import { installSelfHostedMahayanaInvocationBridge } from './selfhosted-mahayana-invocation-bridge';
import './messenger-layout-regressions.css';
import './grok-agent-ui-parity.css';
import './openbot-ui-parity.css';
import './credential-vault.css';
import './sidebar-contact-groups.css';

const root = document.querySelector<HTMLDivElement>('#root');
if (!root) {
  throw new Error('Fabushi desktop root element is missing');
}

async function bootstrapDesktop(rootElement: HTMLDivElement): Promise<void> {
  installDesktopAccountSessionSync();
  // Restore native persisted projections before the transcript reducer reads
  // its first-frame cache. Rust/cloud authority remains the recovery source;
  // localStorage is only a renderer projection for the current migration.
  await restoreDurableAgentState();
  prepareGrokChatParityRuntime();
  installBotIdentityAliases();
  installDesktopMiniAppDiscoveryAliases();
  installDurableAgentState();
  installDesktopMiniAppWebMcpHost();
  installDesktopAppAgentSurface();

  createRoot(rootElement).render(
    <StrictMode>
      <DesktopShellV2 />
      <GrokChatParityRuntime />
      <MahayanaAgentInlineReport />
      <CredentialVault />
    </StrictMode>,
  );

  installMiniAppComposerOpenBridge(rootElement);
  installSelfHostedMahayanaInvocationBridge();
}

void bootstrapDesktop(root).catch((error: unknown) => {
  console.error('Fabushi desktop bootstrap failed', error);
});
