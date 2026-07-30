const hello = (name = 'Mahayana') => ({
  message: `Hello, ${name}!`,
  pluginId: 'cloud-market-hello',
  version: '1.0.0',
  deployment: 'independent-cloudflare-worker',
});

const reply = (id: unknown, result: unknown) => Response.json({ jsonrpc: '2.0', id, result });

export default {
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === '/health') {
      return Response.json({ ok: true, pluginId: 'cloud-market-hello', version: '1.0.0' });
    }
    if (url.pathname !== '/mcp' || request.method !== 'POST') {
      return new Response('Not found', { status: 404 });
    }
    const message = await request.json<Record<string, unknown>>();
    if (message.method === 'initialize') {
      return reply(message.id, {
        protocolVersion: '2025-06-18',
        capabilities: { tools: {} },
        serverInfo: { name: 'cloud-market-hello', version: '1.0.0' },
      });
    }
    if (message.method === 'tools/list') {
      return reply(message.id, {
        tools: [{
          name: 'hello',
          description: 'Return a deterministic greeting from the cloud marketplace mini app.',
          annotations: { readOnlyHint: true },
          inputSchema: {
            type: 'object', additionalProperties: false,
            properties: { name: { type: 'string', minLength: 1, maxLength: 80 } },
          },
        }],
      });
    }
    if (message.method === 'tools/call') {
      const params = message.params as { name?: string; arguments?: { name?: string } } | undefined;
      if (params?.name === 'hello') {
        const result = hello(params.arguments?.name);
        return reply(message.id, {
          content: [{ type: 'text', text: result.message }],
          structuredContent: result,
          isError: false,
        });
      }
    }
    return Response.json({
      jsonrpc: '2.0', id: message.id, error: { code: -32601, message: 'Method not found' },
    });
  },
};
