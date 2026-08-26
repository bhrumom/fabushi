import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { installDesktopAccountSessionSync } from './account-session-sync';
import { installBotIdentityAliases } from './agent-identity-aliases';
import { installDurableAgentState, restoreDurableAgentState } from './durable-agent-state';
import DesktopShellV2 from './messaging-shell-v2';
import MahayanaAgentWorkbench from './mahayana-agent-workbench';
import { installMahayanaAgentTranscriptSemantics } from './mahayana-agent-transcript-semantics';
import { installSelfHostedMahayanaInvocationBridge } from './selfhosted-mahayana-invocation-bridge';
import './messenger-layout-regressions.css';
import './grok-agent-ui-parity.css';
import './mahayana-agent-transcript-semantics.css';

const root = document.querySelector<HTMLDivElement>('#root');
if (!root) {
  throw new Error('Fabushi desktop root element is missing');
}

async function bootstrapDesktop(): Promise<void> {
  installDesktopAccountSessionSync();
  // Restore native/Rust-backed projections before transport/workbench reducers
  // read their first-frame local cache. This keeps localStorage a projection,
  // not the restart authority.
  await restoreDurableAgentState();
  installBotIdentityAliases();
  installDurableAgentState();

  createRoot(root).render(
    <StrictMode>
      <DesktopShellV2 />
      <MahayanaAgentWorkbench />
    </StrictMode>,
  );

  installMahayanaAgentTranscriptSemantics();
  installSelfHostedMahayanaInvocationBridge();
}

void bootstrapDesktop().catch((error: unknown) => {
  console.error('Fabushi desktop bootstrap failed', error);
});
