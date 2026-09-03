# Source — Packaged Messenger sidebar footer regression

On 2026-08-23, the packaged Electron quality gate for the M7 unified desktop shell exposed the same cross-platform UI defect on macOS and Windows: the bottom personal-navigation footer intercepted pointer events intended for a visible assistant peer row. Linux packaging and the Host simulated-user smoke remained green.

The product requirement is unchanged: the left conversation column must resize and collapse to avatar-only mode while the personal-navigation trigger stays at the bottom, without obscuring any conversation. The fix therefore preserves the UI design and corrects flex sizing rather than weakening the Playwright interaction.

The direct-distribution macOS signing repair from PR #2064 is a separate layer. It has already merged to `main`; after this layout regression is green and merged, canonical main packaging must re-run so the fixed Developer ID/nested-identifier/notarization path can produce the package used for local installation.
