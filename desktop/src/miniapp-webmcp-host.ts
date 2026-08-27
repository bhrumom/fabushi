import { invokeNativeDesktop } from '../../frontend/apps/web/src/lib/fabushi-runtime/native-desktop';
import { ElectronMahayanaHostTransport } from '../../frontend/apps/web/src/lib/mahayana-host/electron-transport';
import { readAccountMiniApps } from './account-sync-client';

const protocol = 'fabushi.miniapp.webmcp.v1';
const installMarker = Symbol.for('fabushi.desktop.miniapp-webmcp-host.v1');
const pendingToolCalls = new Set<string>();

type ToolDescriptor = {
  name: string;
  description?: string;
  inputSchema?: Record<string, unknown>;
  annotations?: { readOnlyHint?: boolean; destructiveHint?: boolean; openWorldHint?: boolean };
  approval?: string;
};

type PluginUiDocument = { pluginId: string; html: string };

type MahayanaBridge = {
  invoke<T>(method: string, params?: Record<string, unknown>): Promise<T>;
  subscribe?(listener: (event: any) => void): () => void;
};

declare global {
  interface Window {
    mahayana?: MahayanaBridge;
  }
}

function safePluginId(value: unknown): string {
  const id = String(value ?? '').trim().toLowerCase();
  return /^[a-z0-9][a-z0-9-]{1,63}$/.test(id) ? id : '';
}

function normalizeRuntimeTool(value: unknown): ToolDescriptor | null {
  if (typeof value === 'string' && value.trim()) {
    return { name: value.trim(), inputSchema: { type: 'object', properties: {} } };
  }
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const row = value as Record<string, unknown>;
  const name = String(row.name ?? row.id ?? '').trim();
  if (!name) return null;
  return {
    name,
    description: typeof row.description === 'string' ? row.description : undefined,
    inputSchema: row.inputSchema && typeof row.inputSchema === 'object' && !Array.isArray(row.inputSchema)
      ? row.inputSchema as Record<string, unknown>
      : { type: 'object', properties: {} },
    annotations: row.annotations && typeof row.annotations === 'object' && !Array.isArray(row.annotations)
      ? row.annotations as ToolDescriptor['annotations']
      : undefined,
  };
}

async function allowedTools(pluginId: string): Promise<ToolDescriptor[]> {
  const account = await readAccountMiniApps();
  const app = account.apps.find((candidate) => candidate.id === pluginId);
  if (!app) throw new Error(`MiniApp ${pluginId} is not installed for this account`);

  const runtimeInventory = await invokeNativeDesktop<unknown>('listMcpServerTools', { server: pluginId }).catch(() => []);
  const runtimeRows = Array.isArray(runtimeInventory)
    ? runtimeInventory.map(normalizeRuntimeTool).filter((tool): tool is ToolDescriptor => Boolean(tool))
    : [];

  const commands = Array.isArray(app.commands) ? app.commands : [];
  const commandByTool = new Map<string, Record<string, unknown>>();
  for (const raw of commands) {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) continue;
    const command = raw as Record<string, unknown>;
    const tool = String(command.tool ?? command.name ?? '').trim();
    if (tool) commandByTool.set(tool, command);
  }

  if (runtimeRows.length > 0) {
    return runtimeRows.map((tool) => {
      const command = commandByTool.get(tool.name);
      const approval = String(command?.approval ?? 'none');
      return {
        ...tool,
        description: tool.description || (typeof command?.description === 'string' ? command.description : undefined),
        approval,
        annotations: tool.annotations ?? {
          readOnlyHint: approval === 'none',
          destructiveHint: approval === 'destructive',
          openWorldHint: false,
        },
      };
    });
  }

  return [...commandByTool.entries()].map(([name, command]) => {
    const approval = String(command.approval ?? 'none');
    return {
      name,
      description: typeof command.description === 'string' ? command.description : undefined,
      inputSchema: { type: 'object', properties: {} },
      approval,
      annotations: {
        readOnlyHint: approval === 'none',
        destructiveHint: approval === 'destructive',
        openWorldHint: false,
      },
    };
  });
}

async function callHostMcpTool(pluginId: string, tool: ToolDescriptor, args: Record<string, unknown>): Promise<unknown> {
  const bridge = window.mahayana;
  if (!bridge?.invoke || !bridge.subscribe) throw new Error('Mahayana Host event bridge is unavailable');
  const key = `${pluginId}:${tool.name}`;
  if (pendingToolCalls.has(key)) throw new Error(`Tool ${tool.name} already has a pending call`);
  pendingToolCalls.add(key);

  const approval = tool.approval ?? (tool.annotations?.readOnlyHint === true ? 'none' : 'required');
  if (approval !== 'none') {
    const warning = approval === 'destructive'
      ? '该操作可能产生破坏性修改。'
      : '该操作会修改小程序或后台状态。';
    if (!window.confirm(`允许 ${pluginId} 调用 ${tool.name}？\n\n${warning}`)) {
      pendingToolCalls.delete(key);
      throw new Error('用户取消了 WebMCP Tool 调用');
    }
  }

  return new Promise((resolve, reject) => {
    let timer: ReturnType<typeof setTimeout> | null = null;
    const cleanup = bridge.subscribe?.((event: any) => {
      if (event?.type !== 'mcp.toolResult' || event?.server !== pluginId || event?.tool !== tool.name) return;
      if (timer) clearTimeout(timer);
      cleanup?.();
      pendingToolCalls.delete(key);
      resolve(event.result);
    });
    timer = setTimeout(() => {
      cleanup?.();
      pendingToolCalls.delete(key);
      reject(new Error(`Timed out waiting for ${pluginId}:${tool.name}`));
    }, 30_000);

    void bridge.invoke('feature.execute', {
      command: {
        type: 'mcp.toolCall',
        requestId: `webmcp-${Date.now()}-${Math.random().toString(16).slice(2)}`,
        server: pluginId,
        tool: tool.name,
        arguments: args,
      },
    }).catch((error) => {
      if (timer) clearTimeout(timer);
      cleanup?.();
      pendingToolCalls.delete(key);
      reject(error);
    });
  });
}

function webMcpBootstrap(pluginId: string): string {
  const encodedPluginId = JSON.stringify(pluginId);
  return `<script>(function(){
    const protocol=${JSON.stringify(protocol)};
    const pluginId=${encodedPluginId};
    const pending=new Map(); let sequence=0; const localTools=new Map();
    function request(action,payload){return new Promise((resolve,reject)=>{const requestId='webmcp-'+Date.now()+'-'+(++sequence);pending.set(requestId,{resolve,reject});window.parent.postMessage({protocol,pluginId,requestId,action,...(payload||{})},'*');});}
    function publicTool(tool){const copy={...tool};delete copy.execute;return copy;}
    function register(tool){localTools.set(tool.name,tool);if(document.modelContext&&typeof document.modelContext.registerTool==='function'){document.modelContext.registerTool(tool);}}
    Object.defineProperty(window,'__fabushiWebMcp',{configurable:true,value:{version:1,list:()=>Array.from(localTools.values()).map(publicTool),call:async(name,input={})=>{const tool=localTools.get(name);if(!tool)throw new Error('Unknown WebMCP tool: '+name);return tool.execute(input);}}});
    window.addEventListener('message',(event)=>{const data=event.data||{};if(data.protocol!==protocol||data.pluginId!==pluginId||!data.requestId||!pending.has(data.requestId))return;const task=pending.get(data.requestId);pending.delete(data.requestId);if(data.ok)task.resolve(data.data);else task.reject(new Error(data.error||'WebMCP host request failed'));});
    async function boot(){const tools=await request('list');for(const item of (tools||[])){register({name:item.name,description:item.description,inputSchema:item.inputSchema||{type:'object',properties:{}},annotations:item.annotations||{},execute:(input)=>request('call',{tool:item.name,input:input||{}})});}window.dispatchEvent(new CustomEvent('fabushi:webmcp-ready',{detail:{pluginId,tools:(tools||[]).map(t=>t.name)}}));}
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>void boot());else void boot();
  })();</script>`;
}

function injectWebMcp(html: string, pluginId: string): string {
  if (html.includes('fabushi.miniapp.webmcp.v1')) return html;
  const bootstrap = webMcpBootstrap(pluginId);
  return html.includes('</head>') ? html.replace('</head>', `${bootstrap}</head>`) : `${bootstrap}${html}`;
}

export function installDesktopMiniAppWebMcpHost(): void {
  const globalObject = window as Window & { [installMarker]?: boolean };
  if (globalObject[installMarker]) return;
  Object.defineProperty(globalObject, installMarker, { value: true });

  const prototype = ElectronMahayanaHostTransport.prototype as ElectronMahayanaHostTransport & {
    pluginUiDocument(pluginId: string): Promise<PluginUiDocument>;
  };
  const originalPluginUiDocument = prototype.pluginUiDocument;
  prototype.pluginUiDocument = async function pluginUiDocumentWithWebMcp(pluginId: string) {
    const document = await originalPluginUiDocument.call(this, pluginId);
    return { ...document, html: injectWebMcp(document.html, pluginId) };
  };

  window.addEventListener('message', (event) => {
    const data = event.data as Record<string, unknown> | null;
    if (!data || data.protocol !== protocol || !data.requestId) return;
    const pluginId = safePluginId(data.pluginId);
    const requestId = String(data.requestId);
    const source = event.source;
    if (!pluginId || !source || typeof (source as WindowProxy).postMessage !== 'function') return;

    const respond = (ok: boolean, payload: unknown) => {
      (source as WindowProxy).postMessage({
        protocol,
        pluginId,
        requestId,
        ok,
        ...(ok ? { data: payload } : { error: payload instanceof Error ? payload.message : String(payload) }),
      }, '*');
    };

    void (async () => {
      try {
        const tools = await allowedTools(pluginId);
        if (data.action === 'list') {
          respond(true, tools.map(({ approval: _approval, ...tool }) => tool));
          return;
        }
        if (data.action === 'call') {
          const requested = String(data.tool ?? '').trim();
          const tool = tools.find((candidate) => candidate.name === requested);
          if (!tool) throw new Error(`WebMCP tool ${requested} is not allowed for ${pluginId}`);
          const input = data.input && typeof data.input === 'object' && !Array.isArray(data.input)
            ? data.input as Record<string, unknown>
            : {};
          respond(true, await callHostMcpTool(pluginId, tool, input));
          return;
        }
        throw new Error(`Unsupported WebMCP action ${String(data.action)}`);
      } catch (error) {
        respond(false, error);
      }
    })();
  });
}
