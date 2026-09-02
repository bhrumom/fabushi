# Mobile authentication sheet — 2026-09-02

## Goal

Make Fabushi mobile authentication behave like a native mobile sign-in flow: a mobile-first app landing screen, authentication presented inside the app with the platform browser sheet/custom tab, a responsive touch-first browser portal, reliable return to the app, and recovery from an unreadable stale local account-session store.

## Acceptance

- iOS uses `ASWebAuthenticationSession`; it must not hand browser login to standalone Safari.
- Android uses Custom Tabs; it must not launch a generic external browser intent.
- The unauthenticated mobile surface is light, mobile-first, and does not expose attempt IDs or host/debug errors.
- The hosted login portal becomes cardless/light/touch-first on narrow screens while preserving desktop behavior and all providers/password/registration paths.
- iOS/Android browser starts are identified to the account service as `mobile`.
- A local auth secrets file that can no longer be decrypted is quarantined and treated as signed out so a fresh browser login can recreate the session; managed/requested secrets are not reset.
- Native and shared-host CI gates pass before merge.
- Version is advanced to 1.2.2 and the merged source is delivered through the existing iOS/TestFlight and Google Play workflows, with the auth worker deployed from the same canonical source.

## Evidence

Implementation, CI run links, merged SHA, worker deployment, store-delivery run IDs, and release tags are recorded in the merge/release history. This file is intentionally a durable task anchor rather than a progress log.
