# FCM-002 Evidence

- PR: #1999
- Head: `9878d7a50e96dd38679ace5c53ad4b594f322c53`
- Observer run: `32564046852` — success
- Artifact: `9473581875` / `fcm-ci-latency-32564046852`
- Artifact digest: `sha256:00d4fee80b27d4e0d88c3f597b367a9d3b51a88e019b2d093048d39d793395ba`
- JSON/CSV files: `ci-latency-report.json`, `ci-latency-samples.csv`
- Samples: 50
- fast-path: N=32, P50=13s, P95=22s, queue P95=0s, within 30s budget
- full-canonical: N=14, P50=104s, P95=163s, queue P95=0s, within 1800s budget
- Merge commit: `3a39dfef0ef30f1e6ae2d53602fa862bf28ddae6`
- Canonical workflow blob after merge: `0ff42b21ff6c12e4784279d4ecd9b18544b7a18c`
