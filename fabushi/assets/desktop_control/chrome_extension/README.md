# Dacheng Chrome Connector

Load this folder as an unpacked extension from `chrome://extensions`, then open
the extension options and paste the `bridgeUrl` and `token` from
`dacheng-bridge-config.json`.

The connector exposes tab metadata, visible-page screenshots, sanitized DOM
summaries, and confirmed click/type/navigation actions. It does not read
cookies, passwords, or page localStorage.
