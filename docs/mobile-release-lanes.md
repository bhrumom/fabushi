# Mobile release lanes

Fabushi has two intentionally different mobile release lanes.

## Test release

Use **Mobile test delivery** when the goal is to get a build into testers' hands quickly. The source must come from `main` and normal CI must be green, but the long native simulated-user gates are not prerequisites. The delivery workflow still performs the real signed store build and upload. iOS is uploaded to App Store Connect/TestFlight without App Review submission. Android is uploaded to the Google Play `internal` track.

This lane is for rapid product and UI verification. A test build is not evidence that the full formal-release acceptance suite passed.

## Formal release

Use the existing formal store delivery path for public production releases. It requires the complete release source gate, including native mobile/iOS quality gates and their simulator/emulator simulated-user coverage, plus the other platform checks required by the selected target. Google Play goes to `production`; Apple builds become eligible for App Store release selection only after the formal gate has succeeded.

## Rule

Simulated-user UI testing is a **formal-release prerequisite**, not a **test-release prerequisite**. Both lanes still require canonical `main` ancestry, valid signing/store credentials, and successful package construction/upload.
