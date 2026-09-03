# M7-DESKTOP-003 packaged sidebar footer regression

## Symptom

Packaged Electron E2E on macOS and Windows reached the unified Messenger but the final surface test could not click the active assistant peer. Playwright reported that the bottom personal-navigation footer intercepted pointer events over the peer row.

## Root cause

The peer list was a flex child with the default automatic minimum height. In constrained packaged windows it could retain content height instead of shrinking to the remaining space above the fixed-size footer. The footer therefore painted over the last visible peer rows.

## Repair

- make `.peerList` explicitly shrinkable with `min-height: 0` and `flex: 1 1 auto`;
- constrain the unified chat-list column to the shell height while retaining visible overflow for the personal navigation popover;
- keep the existing real click in `surfaces.spec.ts` as the regression gate rather than forcing the click or weakening the test.

## Required verification

The repair is complete only when packaged Electron E2E passes on macOS and Windows, the canonical main macOS package passes Developer ID signing/notarization/verification, and the resulting signed package is installed and opened on the target Mac.
