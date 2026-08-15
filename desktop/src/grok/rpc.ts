export const EDGE_UNKNOWN_METHOD = 'edge/unknown-method' as const;
export const EDGE_HANDLER_FAILED = 'edge/handler-failed' as const;
export const EDGE_UNTRUSTED_SENDER = 'edge/untrusted-sender' as const;

export type EdgeFailureCode =
  | typeof EDGE_UNKNOWN_METHOD
  | typeof EDGE_HANDLER_FAILED
  | typeof EDGE_UNTRUSTED_SENDER
  | (string & {});

export interface EdgeFailure {
  code: EdgeFailureCode;
  detail: string;
}

export type EdgeEnvelope<T> =
  | { ok: true; value: T }
  | { ok: false; failure: EdgeFailure };

export type EdgeArgsKind = 'none' | 'object';

export interface EdgeMethodSpec {
  readonly args: EdgeArgsKind;
}

export interface EdgeDescriptor<
  TMethods extends Record<string, EdgeMethodSpec>,
  TEvents extends readonly string[] = readonly [],
> {
  readonly edge: string;
  readonly methods: TMethods;
  readonly events: TEvents;
  readonly hasEvents: boolean;
}

export function defineEdge<
  const TMethods extends Record<string, EdgeMethodSpec>,
  const TEvents extends readonly string[],
>(edge: string, methods: TMethods, events: TEvents): EdgeDescriptor<TMethods, TEvents> {
  return { edge, methods, events, hasEvents: events.length > 0 };
}

export function methodChannel(edge: string, method: string): string {
  return `sand-rpc:${edge}:m:${method}`;
}

export function eventChannel(edge: string, event: string): string {
  return `sand-rpc:${edge}:e:${event}`;
}

export function isEdgeEnvelope(value: unknown): value is EdgeEnvelope<unknown> {
  return typeof value === 'object'
    && value !== null
    && 'ok' in value
    && typeof (value as { ok?: unknown }).ok === 'boolean';
}

export class EdgeCallFailure extends Error {
  readonly code: EdgeFailureCode;
  readonly detail: string;

  constructor(failure: EdgeFailure) {
    super(`${failure.code}: ${failure.detail}`);
    this.name = 'EdgeCallFailure';
    this.code = failure.code;
    this.detail = failure.detail;
  }
}
