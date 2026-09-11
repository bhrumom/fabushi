#!/usr/bin/env python3
"""Exercise the real Debug Mahayana JSONL backend, not an emulated backend."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
workspace = root / 'third_party/mahayana/mahayana-rs'
methods = ['resetProfile', 'health', 'logs.query', 'events.subscribe', 'shutdown']
requests = [{'protocol': 'mahayana.test-driver.v1', 'requestId': f'fast-{i}',
             'correlationId': f'fast-correlation-{i}', 'method': method,
             'params': {'afterSequence': 0} if method in {'logs.query', 'events.subscribe'} else {}}
            for i, method in enumerate(methods)]
with tempfile.TemporaryDirectory(prefix='fabushi-driver-') as directory:
    marker = Path(directory) / 'stale-state.txt'
    marker.write_text('isolated test state')
    env = {**os.environ, 'MAHAYANA_TEST_DRIVER_ROOT': directory, 'CARGO_PROFILE_CI_DEBUG_ASSERTIONS': 'true'}
    completed = subprocess.run(['cargo', 'run', '--locked', '--quiet', '--profile', 'ci', '-p', 'mahayana-cli',
                                '--features', 'test-driver', '--bin', 'mahayana-test-driver'],
                               cwd=workspace, env=env, input=''.join(json.dumps(r) + '\n' for r in requests),
                               text=True, stdout=subprocess.PIPE, check=True, timeout=1200)
    replies = [json.loads(line) for line in completed.stdout.splitlines() if line.strip()]
    if len(replies) != len(requests):
        raise RuntimeError('missing or extra JSONL replies')
    for request, reply in zip(requests, replies):
        if reply.get('ok') is not True or reply.get('correlationId') != request['correlationId']:
            raise RuntimeError('failed or incorrectly correlated response')
    health = replies[1]['result']
    if health.get('backend') != 'mahayana-product-core' or health.get('debugOnly') is not True:
        raise RuntimeError('not the expected real Debug product backend')
    if marker.exists() or replies[-1]['result'].get('shutdownRequested') is not True:
        raise RuntimeError('reset/shutdown lifecycle failed')
    if not replies[2]['result'].get('entries') or not replies[3]['result'].get('events'):
        raise RuntimeError('missing logs/events evidence')
    print(json.dumps({'backend': health['backend'], 'methods': methods,
                      'scope': 'real backend control-plane lifecycle; not all product features'}))
    print('FABUSHI_DRIVER_SMOKE_PASSED')
