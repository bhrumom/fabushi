{
  "version": 1,
  "boundaries": [
    "renderer->preload",
    "preload->Electron main edge",
    "Electron main->Rust AppHost",
    "FeatureHost->MahayanaRuntime/tool backend",
    "remote mobile->desktop session",
    "browser extension->claimed tab/CDP target",
    "sensitive widget->device secure channel"
  ],
  "threats": [
    {
      "id": "T01",
      "threat": "renderer arbitrary IPC / confused deputy",
      "mitigation": "per-method versioned edge plus trusted-sender validation; generic fabushi:host removed",
      "residual": "a compromised trusted renderer can request only declared capabilities; downstream capability policy still applies"
    },
    {
      "id": "T02",
      "threat": "tool/local-exec privilege bypass",
      "mitigation": "single FeatureHost path, local_execution and AI-control gates, permission ceiling/approval, direct runtime.callTool removed",
      "residual": "approved tools retain only their declared scoped side effects"
    },
    {
      "id": "T03",
      "threat": "remote-control replay / target drift",
      "mitigation": "active session plus device id plus monotonic generation plus target kind/protocol binding",
      "residual": "an authenticated active peer remains limited by the pairing and authorization boundary"
    },
    {
      "id": "T04",
      "threat": "browser wrong-tab control",
      "mitigation": "claim-bound target/tab identity, extension generation, CDP child-session routing and per-tab queues",
      "residual": "browser or extension compromise outside the Fabushi process remains an endpoint risk"
    },
    {
      "id": "T05",
      "threat": "sensitive-input replay or disclosure",
      "mitigation": "ECDH P-256 to AES-GCM, challenge AAD binding, optional expiry, one-time consume and reconnect key rotation",
      "residual": "endpoint compromise after local decryption is outside the transport guarantee"
    },
    {
      "id": "T06",
      "threat": "secret or credential leakage through diagnostics",
      "mitigation": "edge traces exclude args/results/URLs/tokens, native diagnostics recursively redact sensitive keys, secret vault uses OS-backed encryption",
      "residual": "OS or debugger compromise can observe data after authorization"
    },
    {
      "id": "T07",
      "threat": "attachment path traversal or insecure model/content download",
      "mitigation": "managed-root containment, HTTPS-only downloads and SHA-256 validation for offline ASR model acquisition",
      "residual": "authorized remote HTTPS content is still untrusted data and must not become executable code implicitly"
    },
    {
      "id": "T08",
      "threat": "unlicensed or ambiguous Grok source shipped as Fabushi product code",
      "mitigation": "historical Grok 0.20 snapshot is absent from production tree and all 148 entries remain PROVENANCE_BLOCKED/reference-only with CI fail-closed if vendor paths return",
      "residual": "historical Git objects remain audit inputs but are not release artifacts or runtime authorities"
    }
  ]
}
