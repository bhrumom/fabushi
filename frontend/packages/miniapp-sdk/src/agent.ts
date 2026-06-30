import type { AnyRecord, AgentStatus } from "./types";
import type { HostInvoker } from "./auth";

export interface AgentInstallInput extends AnyRecord {
  agentId: string;
  deviceId?: string;
  version?: string;
  acceptedPermissions?: string[];
}

export interface AgentCommandInput extends AnyRecord {
  agentId: string;
  installId?: string;
  sessionId?: string;
  text?: string;
  command?: string;
  payload?: AnyRecord;
}

export class AgentModule {
  private readonly invoke: HostInvoker;

  constructor(invoke: HostInvoker) {
    this.invoke = invoke;
  }

  install(input: AgentInstallInput): Promise<AnyRecord> {
    return this.invoke("agent.install", input);
  }

  status(agentId: string, installId?: string): Promise<AgentStatus> {
    return this.invoke("agent.status", { agentId, installId });
  }

  sendCommand(input: AgentCommandInput): Promise<AnyRecord> {
    return this.invoke("agent.sendCommand", input);
  }

  continueTask(taskId: string, params: AnyRecord = {}): Promise<AnyRecord> {
    return this.invoke("agent.continueTask", { taskId, ...params });
  }

  openConfig(agentId: string, installId?: string): Promise<AnyRecord> {
    return this.invoke("agent.openConfig", { agentId, installId });
  }

  getLogs(agentId: string, installId?: string, limit = 200): Promise<AnyRecord> {
    return this.invoke("agent.getLogs", { agentId, installId, limit });
  }

  cancelTask(taskId: string, reason?: string): Promise<AnyRecord> {
    return this.invoke("agent.cancelTask", { taskId, reason });
  }
}
