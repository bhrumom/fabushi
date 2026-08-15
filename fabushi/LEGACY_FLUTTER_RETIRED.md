# Legacy Flutter application — retired

This directory is retained temporarily as migration/reference source only.

It is **not** a build, package, version, deployment, marketplace, or CI source
of truth. The canonical application shell is now `../mobile/`:

- React/Vite UI
- Tauri 2 desktop + iOS + Android shell
- Mahayana Rust Host
- `mahayana-plugin-runtime`
- embedded `mahayana-js-runtime` for portable DeepSeek/Cordis compatibility

Do not add new product functionality to this Flutter tree. A still-required
legacy capability must be migrated behind the Rust Host or a Tauri/native/Web
adapter and recorded in `../mobile/CAPABILITY_PARITY.md`.

The directory can be physically deleted once the remaining product capability
migration decisions in that parity document have been completed. Active CI/CD
prevents Flutter from becoming a canonical application dependency again.
