# GBF-504 Evidence

Engine observes `prefers-reduced-motion`, pauses continuous motion offscreen with IntersectionObserver, cancels the global RAF when there are no subscribers, and avoids pointer-follow listeners in sidebar list marks. CI rejects `setInterval` legacy loops.
