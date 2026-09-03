# GBF-802 Evidence — rollback drill

`gbf-rollback-drill.yml` proves that a real previously published stable GitHub release is a usable rollback target instead of merely documenting a rollback idea. It resolves `releases/latest`, rejects draft/prerelease targets, resolves the tag to a commit, downloads the release assets, requires `SHA256SUMS.txt`, and validates every published checksum after normalizing the release-path prefix.

The same drill verifies that the current canonical release workflow still requires CI/Electron/Native Mobile and refuses to mutate an already existing release. If there is no prior stable release, no assets, or no checksum file, the drill fails closed and GBF-802 remains blocked rather than being marked complete.
