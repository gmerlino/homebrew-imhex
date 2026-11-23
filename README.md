# Homebrew ImHex

Source-built ImHex 1.38.1 for macOS, pinned to upstream commit
`76cf8771158012095d3b3ed58cc93c27ccfac7df`, including its recursive submodules.
Official patterns are pinned to `4646e4b9653c8b208024c5285b00f3084684021c`.

```sh
brew install --formula gmerlino/imhex/imhex
open /opt/homebrew/opt/imhex/imhex.app
brew test gmerlino/imhex/imhex
brew linkage --test gmerlino/imhex/imhex
```

Configuration, workspaces, patterns, scripts and user plugins remain in
`~/Library/Application Support/imhex`. Back up this directory and your existing
application before switching. Do not uninstall the cask with `--zap`.

The formula compiles the release's macOS plugin set: builtin, decompression,
diffing, disassembler, hashes, remote access, C scripting, visualizers and YARA,
plus fonts and UI libraries. The optional .NET scripting component is absent
from the upstream macOS cask and is not enabled here. Binary third-party plugins
may require rebuilding for the compiler ABI; merely copying them does not prove
compatibility.

Build adjustments add explicit C++ headers required by recent libc++, keep the
SDK C headers after libc++ wrappers, use the libmagic library found by CMake, and
allow the Apple SDK's elaborated-enum extension with LLVM 23. Warnings are not
promoted to errors. No application feature is disabled by these adjustments.

The build runs local upstream CTest tests. Three remote-service tests
(StoreAPI, TipsAPI and ContentAPI) are excluded from the reproducible build test;
they depend on live upstream endpoints. The app is locally ad-hoc signed, not
Apple-notarized. Bundled dependencies are assembled using upstream's macOS
packaging procedure.

## Validation on Apple Silicon, 2026-11-23

- Formula compiled from source with LLVM 23.1.6.
- All 23 local upstream tests passed; the three remote endpoint tests were excluded.
- Installed formula test passed: version, SHA-256 of `abc`, calculator and all nine plugins.
- Pattern Language decoded known bytes, checked their values and loaded the bundled standard library.
- Code signature, Homebrew linkage and missing-dependency checks passed.
- GUI displayed the 256-byte fixture correctly; the automated GUI input tool could
  not operate the window. The user verified editing the first byte from 00 to FF,
  saving and reopening the file with FF preserved.
- The original 18 user-data files are unchanged; the old app and data were backed up.
- After manual verification, the old cask was removed without `--zap`.
  `/Applications/ImHex.app` now links to the formula app; user data and backups remain intact.

On macOS, test profiles set both HOME and CFFIXED_USER_HOME. CLI tests use a
pseudo-terminal because upstream otherwise redirects output to a log file.
The formula's build environment must not inherit ROS Kilted's pkg-config paths.

The optional SDK is installed with the app. Existing user plugin directories are
preserved; no third-party plugin binaries were present in this migration.
