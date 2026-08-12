import type {
  ApprovalResolution,
  CommandAccepted,
  HostConfig,
  HostInfo,
  RuntimeCommand,
  RuntimeEvent,
} from "./contracts";

export type RuntimeEventListener = (event: RuntimeEvent) => void;

export interface MahayanaHostTransport {
  initialize(config: HostConfig): Promise<HostInfo>;
  execute(command: RuntimeCommand): Promise<CommandAccepted>;
  subscribe(listener: RuntimeEventListener): () => void;
  interrupt(operationId: string): Promise<void>;
  resolveApproval(resolution: ApprovalResolution): Promise<void>;
  close(): Promise<void>;
}
