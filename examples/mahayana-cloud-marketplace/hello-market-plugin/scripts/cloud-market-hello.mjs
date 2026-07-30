#!/usr/bin/env node
import { pathToFileURL } from 'node:url';

export const helloResult = (name = 'Mahayana') => ({
  message: `Hello, ${name}!`,
  pluginId: 'cloud-market-hello',
  version: '1.0.0',
  deployment: 'independent-cloudflare-worker',
});

const send = payload => process.stdout.write(`${JSON.stringify(payload)}\n`);

export const handleRequest = request => {
  if (request.method === 'initialize') {
    return {
      jsonrpc: '2.0',
      id: request.id,
      result: {
        protocolVersion: '2025-06-18',
        capabilities: { tools: {} },
        serverInfo: { name: 'cloud-market-hello', version: '1.0.0' },
      },
    };
  }
  if (request.method === 'tools/list') {
    return {
      jsonrpc: '2.0',
      id: request.id,
      result: {
        tools: [{
          name: 'hello',
          description: 'Return a deterministic greeting from the installed cloud marketplace mini app.',
          annotations: { readOnlyHint: true },
          inputSchema: {
            type: 'object',
            additionalProperties: false,
            properties: { name: { type: 'string', minLength: 1, maxLength: 80 } },
          },
        }],
      },
    };
  }
  if (request.method === 'tools/call' && request.params?.name === 'hello') {
    const result = helloResult(request.params.arguments?.name || 'Mahayana');
    return {
      jsonrpc: '2.0',
      id: request.id,
      result: {
        content: [{ type: 'text', text: result.message }],
        structuredContent: result,
        isError: false,
      },
    };
  }
  if (request.id !== undefined) {
    return { jsonrpc: '2.0', id: request.id, error: { code: -32601, message: 'Method not found' } };
  }
  return null;
};

export const serve = async () => {
  process.stdin.setEncoding('utf8');
  let buffer = '';
  for await (const chunk of process.stdin) {
    buffer += chunk;
    const lines = buffer.split(/\r?\n/);
    buffer = lines.pop() || '';
    for (const line of lines) {
      if (!line.trim()) continue;
      const response = handleRequest(JSON.parse(line));
      if (response) send(response);
    }
  }
};

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [command] = process.argv.slice(2);
  if (command === 'mcp-serve') {
    await serve();
  } else if (command === 'hello') {
    send(helloResult(process.argv[3] || 'Mahayana'));
  } else {
    process.stderr.write('Usage: cloud-market-hello.mjs mcp-serve | hello [name]\n');
    process.exitCode = 2;
  }
}
