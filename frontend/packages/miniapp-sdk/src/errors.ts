import type { AnyRecord, HostInvokeFailure } from "./types";

export class MiniAppHostError extends Error {
  readonly code: string;
  readonly requestId?: string;
  readonly recoverable: boolean;
  readonly retryAfterMs: number;
  readonly details?: AnyRecord;
  readonly data?: unknown;

  constructor(options: {
    code: string;
    message: string;
    requestId?: string;
    recoverable?: boolean;
    retryAfterMs?: number;
    details?: AnyRecord;
    data?: unknown;
  }) {
    super(options.message);
    this.name = "MiniAppHostError";
    this.code = options.code;
    this.requestId = options.requestId;
    this.recoverable = options.recoverable ?? false;
    this.retryAfterMs = options.retryAfterMs ?? 0;
    this.details = options.details;
    this.data = options.data;
  }
}

function asRecord(value: unknown): AnyRecord | null {
  return value && typeof value === "object" ? (value as AnyRecord) : null;
}

export function normalizeHostError(response: HostInvokeFailure | unknown): MiniAppHostError {
  const record = asRecord(response);
  if (!record) {
    return new MiniAppHostError({
      code: "host_error",
      message: "宿主调用失败",
    });
  }

  const error = asRecord(record.error);
  const requestId = typeof record.requestId === "string" ? record.requestId : undefined;
  if (error) {
    return new MiniAppHostError({
      code: typeof error.code === "string" ? error.code : "host_error",
      message: typeof error.message === "string" ? error.message : "宿主调用失败",
      requestId,
      recoverable: error.recoverable === true,
      retryAfterMs: typeof error.retryAfterMs === "number" ? error.retryAfterMs : 0,
      details: asRecord(error.details) ?? undefined,
      data: record.data,
    });
  }

  return new MiniAppHostError({
    code: typeof record.errorCode === "string" ? record.errorCode : "host_error",
    message: typeof record.message === "string" ? record.message : "宿主调用失败",
    requestId,
    data: record.data,
  });
}

export function isMiniAppHostError(error: unknown): error is MiniAppHostError {
  return error instanceof MiniAppHostError;
}

export function isUnknownMethod(error: unknown): boolean {
  return isMiniAppHostError(error) && error.code === "unknown_method";
}

export function isPermissionDenied(error: unknown): boolean {
  return isMiniAppHostError(error) && error.code === "permission_denied";
}
