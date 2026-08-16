import type {
  ApprovalResolution,
  AuthState,
  AuthProvider,
  BrowserLoginAttempt,
  BrowserLoginPollResult,
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
  browserLoginStart(): Promise<BrowserLoginAttempt>;
  browserLoginPoll(attemptId: string): Promise<BrowserLoginPollResult>;
  oauthStart(provider: AuthProviderId): Promise<OAuthAttempt>;
  oauthPoll(attemptId: string): Promise<OAuthPollResult>;
  openExternal(url: string): Promise<void>;
  openSystemSettings(pane: "screen-recording" | "accessibility"): Promise<void>;
  windowFocused(): Promise<boolean>;
  showNotification(title: string, body: string): Promise<void>;
  passwordLogin(username: string, password: string): Promise<AuthState>;
  logout(): Promise<AuthState>;
  subscribe(listener: RuntimeEventListener): () => void;
  interrupt(operationId: string): Promise<void>;
  resolveApproval(resolution: ApprovalResolution): Promise<void>;
  close(): Promise<void>;
}
