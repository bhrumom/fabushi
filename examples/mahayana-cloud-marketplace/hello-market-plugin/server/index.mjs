import readline from 'node:readline';
import worker from '../worker/src/index.ts';

const lines = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });

for await (const line of lines) {
  if (!line.trim()) continue;

  let rpc;
  try {
    rpc = JSON.parse(line);
  } catch (error) {
    process.stdout.write(`${JSON.stringify({
      jsonrpc: '2.0',
      id: null,
      error: { code: -32700, message: String(error) },
    })}\n`);
    continue;
  }

  const response = await worker.fetch(new Request('https://standalone.invalid/mcp', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(rpc),
  }));

  if (rpc.id === undefined || response.status === 202 || response.status === 204) continue;
  const body = await response.text();
  if (body.trim()) process.stdout.write(`${body}\n`);
}
