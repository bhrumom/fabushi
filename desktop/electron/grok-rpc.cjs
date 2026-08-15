'use strict';

const EDGE_UNKNOWN_METHOD = 'edge/unknown-method';
const EDGE_HANDLER_FAILED = 'edge/handler-failed';
const EDGE_UNTRUSTED_SENDER = 'edge/untrusted-sender';

class EdgeCallFailure extends Error {
  constructor(failure) {
    super(`${failure.code}: ${failure.detail}`);
    this.name = 'EdgeCallFailure';
    this.code = failure.code;
    this.detail = failure.detail;
  }
}

function methodChannel(edge, method) {
  return `sand-rpc:${edge}:m:${method}`;
}

function eventChannel(edge, event) {
  return `sand-rpc:${edge}:e:${event}`;
}

function isEnvelope(value) {
  return value != null && typeof value === 'object' && typeof value.ok === 'boolean';
}

function toFailure(code, error) {
  return {
    code,
    detail: error instanceof Error ? error.message : String(error),
  };
}

function createElectronRendererEdgeClient(ipcRenderer, descriptor) {
  const client = {};

  async function invoke(method, args) {
    let response;
    try {
      response = await ipcRenderer.invoke(methodChannel(descriptor.edge, method), args);
    } catch (error) {
      throw new EdgeCallFailure(toFailure(EDGE_UNKNOWN_METHOD, error));
    }
    if (!isEnvelope(response)) {
      throw new EdgeCallFailure({
        code: EDGE_HANDLER_FAILED,
        detail: 'The edge replied outside its envelope.',
      });
    }
    if (response.ok) return response.value;
    throw new EdgeCallFailure(response.failure);
  }

  for (const [method, spec] of Object.entries(descriptor.methods)) {
    client[method] = spec.args === 'none'
      ? () => invoke(method, {})
      : (args = {}) => invoke(method, args);
  }

  if (descriptor.events.length > 0) {
    client.subscribe = (listeners) => {
      const disposers = [];
      for (const [event, listener] of Object.entries(listeners || {})) {
        if (typeof listener !== 'function' || !descriptor.eventSet.has(event)) continue;
        const channel = eventChannel(descriptor.edge, event);
        const wrapped = (_electronEvent, payload) => listener(payload);
        ipcRenderer.on(channel, wrapped);
        disposers.push(() => ipcRenderer.off(channel, wrapped));
      }
      return () => {
        for (const dispose of disposers) dispose();
      };
    };
  }

  return Object.freeze(client);
}

function serveElectronMainEdge(ipcMain, descriptor, handlers, options = {}) {
  const channels = [];

  for (const method of Object.keys(descriptor.methods)) {
    const channel = methodChannel(descriptor.edge, method);
    channels.push(channel);
    ipcMain.handle(channel, async (event, args) => {
      if (options.isTrustedSender && !options.isTrustedSender(event)) {
        return { ok: false, failure: { code: EDGE_UNTRUSTED_SENDER, detail: 'Rejected IPC sender.' } };
      }
      const handler = handlers[method];
      if (typeof handler !== 'function') {
        return { ok: false, failure: { code: EDGE_UNKNOWN_METHOD, detail: `Unknown edge method: ${method}` } };
      }
      try {
        return { ok: true, value: await handler(args ?? {}, event) };
      } catch (error) {
        options.onHandlerError?.(method, error);
        return { ok: false, failure: toFailure(EDGE_HANDLER_FAILED, error) };
      }
    });
  }

  return Object.freeze({
    emit(webContents, event, payload) {
      if (!descriptor.eventSet.has(event)) throw new Error(`Unknown edge event: ${event}`);
      webContents.send(eventChannel(descriptor.edge, event), payload);
    },
    dispose() {
      for (const channel of channels) ipcMain.removeHandler(channel);
    },
  });
}

function defineEdge(edge, methods, events = []) {
  const eventList = Object.freeze([...events]);
  return Object.freeze({
    edge,
    hasEvents: eventList.length > 0,
    methods: Object.freeze({ ...methods }),
    events: eventList,
    eventSet: new Set(eventList),
  });
}

module.exports = {
  EDGE_UNKNOWN_METHOD,
  EDGE_HANDLER_FAILED,
  EDGE_UNTRUSTED_SENDER,
  EdgeCallFailure,
  createElectronRendererEdgeClient,
  defineEdge,
  eventChannel,
  methodChannel,
  serveElectronMainEdge,
};
