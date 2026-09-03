# GBF-604 Evidence

Local baseline: 20,000 in-process edge calls averaged ~3-4 microseconds on the development machine; CI budget is deliberately generous at 500 microseconds average to catch severe regressions without runner-noise flakes. `edge-ipc.bench.cjs` runs in CI and Electron Desktop workflow.
