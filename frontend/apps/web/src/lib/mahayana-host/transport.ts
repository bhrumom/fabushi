import type {
  ApprovalResolution,
  AuthState,
  AuthProvider,
  AuthProviderId,
  CommandAccepted,
  HostConfig,
  HostInfo,
  RuntimeCommand,
  RuntimeEvent,
  OAuthAttempt,
  OAuthPollResult,
} from "./contracts";

export type RuntimeEventListener = (event: RuntimeEvent) => void;

export interface MahayanaHostTransport {
  initialize(config: HostConfig): Promise<HostInfo>;
  execute(command: RuntimeCommand): Promise<CommandAccepted>;
  authStatus(): Promise<AuthState>;
  authProviders(): Promise<AuthProvider[]>;
  oauthStart(provider: AuthProviderId): Promise<OAuthAttempt>;
  oauthPoll(attemptId: string): Promise<OAuthPollResult>;
  openExternal(url: string): Promise<void>;
  passwordLogin(username: string, password: string): Promise<AuthState>;
  logout(): Promise<AuthState>;
  subscribe(listener: RuntimeEventListener): () => void;
  interrupt(operationId: string): Promise<void>;
  resolveApproval(resolution: ApprovalResolution): Promise<void>;
  close(): Promise<void>;
}
