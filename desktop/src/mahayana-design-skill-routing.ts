import { invokeNativeDesktop } from '../../frontend/apps/web/src/lib/fabushi-runtime/native-desktop';

type DesignPackage = {
  manifest: { id: string; name?: string };
  design: string;
  tokens: string;
};

type StagedSkill = {
  id: string;
  root: string;
  source: string;
  isolated: boolean;
};

type MahayanaBridge = {
  contractVersion: number;
  invoke<T>(method: string, params?: Record<string, unknown>): Promise<T>;
};

type ChatCommand = {
  type: 'chat.send';
  requestId?: string;
  text: string;
  agentId?: string;
  conversationId?: string;
  [key: string]: unknown;
};

const ROUTER_MARKER = '[Fabushi Design Skill activated]';
const INSTALL_KEY = '__fabushiDesignSkillRoutingInstalled';

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value);
}

export function isFabushiDesignIntent(text: string): boolean {
  const normalized = text.trim().toLocaleLowerCase();
  if (!normalized || normalized.includes(ROUTER_MARKER.toLocaleLowerCase())) return false;
  return /(?:设计|界面|ui\b|ux\b|小程序|mini\s*app|网页|网站|landing\s*page|dashboard|仪表盘|原型|prototype|artifact|pptx?|幻灯片|演示文稿|deck\b|海报|封面|视觉|design\s*system|design\b)/i.test(normalized);
}

function workspaceIdFor(command: ChatCommand): string {
  const source = command.agentId || command.conversationId || 'mahayana-assistant';
  const slug = source.replace(/[^a-zA-Z0-9._-]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 96);
  return slug || 'mahayana-assistant';
}

function designPrompt(command: ChatCommand, design: DesignPackage, staged: StagedSkill): string {
  return `${ROUTER_MARKER}
You are still running inside the single Mahayana Runtime. This is design context, not a second agent loop.

Staged portable Skill root: ${staged.root}
Read ${staged.root}/SKILL.md and any referenced files before implementing the design task. Treat the staged copy as read-only input; write deliverables to the active project/workspace.

[Canonical Fabushi DESIGN.md]
${design.design}

[Canonical Fabushi tokens.css]
${design.tokens}

[Artifact delivery contract]
Produce real project files. For generated web/dashboard/MiniApp/deck/document outputs, also write an artifact manifest using schemaVersion "mahayana-artifact/v1" with a safe relative entrypoint, artifact kind, designSystemId "fabushi", and only export formats that the Host reports as available. MiniApps must remain on the existing Fabushi MiniApp/WebMCP/marketplace path.

[User request]
${command.text}`;
}

async function enrichFeatureExecute(params: Record<string, unknown>): Promise<Record<string, unknown>> {
  const commandValue = params.command;
  if (!isRecord(commandValue) || commandValue.type !== 'chat.send' || typeof commandValue.text !== 'string') return params;
  const command = commandValue as ChatCommand;
  if (!isFabushiDesignIntent(command.text)) return params;

  try {
    const [design, staged] = await Promise.all([
      invokeNativeDesktop<DesignPackage>('getDesignSystem', { id: 'fabushi' }),
      invokeNativeDesktop<StagedSkill>('stageDesignSkill', {
        skillId: 'fabushi-design',
        workspaceId: workspaceIdFor(command),
      }),
    ]);
    return {
      ...params,
      command: {
        ...command,
        text: designPrompt(command, design, staged),
      },
    };
  } catch (error) {
    // Enrichment must never create a hidden filesystem or permission bypass.
    // If the trusted Host refuses the package, the ordinary Mahayana turn
    // remains available and no untrusted replacement source is attempted.
    console.warn('Fabushi design Skill enrichment unavailable', error);
    return params;
  }
}

export function installMahayanaDesignSkillRouting(): void {
  if (typeof window === 'undefined') return;
  const target = window as typeof window & {
    mahayana?: MahayanaBridge;
    __fabushiDesignSkillRoutingInstalled?: boolean;
  };
  if (target[INSTALL_KEY as '__fabushiDesignSkillRoutingInstalled'] || !target.mahayana?.invoke) return;

  const bridge = target.mahayana;
  const originalInvoke = bridge.invoke.bind(bridge);
  bridge.invoke = async function routedInvoke<T>(method: string, params?: Record<string, unknown>): Promise<T> {
    if (method === 'feature.execute' && params) {
      return originalInvoke<T>(method, await enrichFeatureExecute(params));
    }
    return originalInvoke<T>(method, params);
  };
  target.__fabushiDesignSkillRoutingInstalled = true;
}
