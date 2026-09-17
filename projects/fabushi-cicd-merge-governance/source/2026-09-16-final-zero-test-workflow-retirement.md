# FCM-024 final zero-test workflow retirement

The 16 legacy workflow files detected as still containing automatically-triggered product tests, regression suites, E2E, or long-running validation were retired from automatic execution. Their replacement definitions are manual-only no-op notices and do not execute product tests.

Formal runtime validation is exclusively performed by `.github/workflows/interactive-runner-mcp.yml`: install and launch the exact release candidate on the Action Runner, allow the bundled Fabushi runtime to register an App-owned device, then drive validation externally through the Fabushi official MCP and finish the CI session with evidence.

Test/beta/prerelease delivery itself performs no behavioral tests. Stable/formal promotion remains blocked unless the exact candidate passes the official-MCP device validation.

The candidate version after this cleanup is 1.2.68 (Android version code 37, iOS build 37).
