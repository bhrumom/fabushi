import type {
  ApprovalResolution,
  AuthState,
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
  authStatus(): Promise<AuthState>;
  passwordLogin(username: string, password: string): Promise<AuthState>;
  logout(): Promise<AuthState>;
  subscribe(listener: RuntimeEventListener): () => void;
  interrupt(operationId: string): Promise<void>;
  resolveApproval(resolution: ApprovalResolution): Promise<void>;
  close(): Promise<void>;
}
