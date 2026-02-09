# Bundling ChessCLI as a Standalone Executable

## Goal

Use `bun build --compile` to produce a single self-contained binary from the Gleam-compiled JavaScript, so users can run `./chesscli` without installing Bun or Gleam.

## Current Build Pipeline

```
gleam build --target javascript
  → build/dev/javascript/chesscli/chesscli.mjs   (entry point)
  → build/dev/javascript/chesscli/**/*.mjs        (app modules + FFI)
  → build/dev/javascript/{gleam_stdlib,etch,...}/  (dependency modules)
  → build/dev/javascript/prelude.mjs              (Gleam runtime)

gleam run --target javascript
  → bun build/dev/javascript/chesscli/chesscli.mjs
```

## Approach

### 1. Add a `build.sh` script

A thin shell script that runs the Gleam build then invokes `bun build --compile`:

```sh
#!/usr/bin/env bash
set -euo pipefail

gleam build --target javascript

bun build --compile --bytecode \
  --outfile chesscli \
  build/dev/javascript/chesscli/chesscli.mjs
```

- `--compile` bundles everything (all imports, Gleam runtime, FFI) into one binary
- `--bytecode` pre-compiles JS to bytecode for faster startup (~2x)
- No `--minify` needed since this isn't served to browsers

### 2. Fix `process.cwd()` dependency for sound files

`sound_ffi.mjs` resolves sound files relative to `process.cwd()`:

```js
const soundDir = join(process.cwd(), "priv", "sound", "lisp");
```

This breaks in a standalone binary because `cwd` won't be the project root. Two options:

**Option A (recommended): Embed sound files into the binary**

Bun supports embedding files at compile time. Change `sound_ffi.mjs` to use `import.meta.dir` or embed with `Bun.file()`:

```js
const soundDir = join(import.meta.dir, "..", "..", "priv", "sound", "lisp");
```

With `--compile`, `import.meta.dir` resolves to the directory of the source file at build time, and Bun embeds referenced files. However, since `afplay` needs a real file path, the simplest approach is:

```js
import move_sound from "../../../priv/sound/lisp/Move.mp3" with { type: "file" };
import capture_sound from "../../../priv/sound/lisp/Capture.mp3" with { type: "file" };
import check_sound from "../../../priv/sound/lisp/Check.mp3" with { type: "file" };

const files = { move: move_sound, capture: capture_sound, check: check_sound, castle: move_sound };

export function play_sound(type) {
  const path = files[type] || files.move;
  try { spawn(["afplay", path]); } catch (_) {}
}
```

Bun's `{ type: "file" }` imports extract embedded assets to a temp directory at runtime and return the real filesystem path, which `afplay` can read.

**Option B: Skip sounds in the binary**

Since sounds are optional (failures are silently caught), the simplest path is to just let them fail gracefully. Sound works when running from the project directory, and silently degrades in the standalone binary.

### 3. External dependencies

The binary still requires these to be installed on the user's machine:

- **Stockfish** — spawned as `Bun.spawn(["stockfish"])`, must be on PATH. This is intentional; Stockfish is ~100MB and platform-specific, not suitable for embedding.
- **afplay** (macOS only) — for move sounds. Comes with macOS, no action needed.

### 4. Cross-platform builds (future)

Bun supports cross-compilation targets:

```sh
bun build --compile --target=bun-darwin-arm64 ...   # macOS Apple Silicon
bun build --compile --target=bun-darwin-x64 ...     # macOS Intel
bun build --compile --target=bun-linux-x64 ...      # Linux x64
bun build --compile --target=bun-linux-arm64 ...    # Linux ARM64
```

Terminal raw mode (used by etch) works on macOS and Linux. Windows is not supported by etch.

## Implementation Steps

1. **Verify basic compile works** — run `bun build --compile build/dev/javascript/chesscli/chesscli.mjs --outfile /tmp/chesscli` and test the binary
2. **Fix sound paths** — choose Option A or B above, update `sound_ffi.mjs`
3. **Add `build.sh`** — script that runs `gleam build` then `bun build --compile`
4. **Test the binary** — verify TUI, Stockfish integration, puzzle persistence, and sounds all work from an arbitrary directory
5. **Document in README** — add build instructions

## Expected Issues

- **etch terminal handling**: etch uses Node-compatible TTY APIs which Bun supports, but worth testing that raw mode, alternate screen, and event reading all work in the compiled binary
- **Gleam runtime imports**: the relative import paths in compiled Gleam output (e.g., `import * from "../gleam_stdlib/..."`) must all resolve during bundling — `bun build` follows these automatically
- **Binary size**: expect ~50-90MB (Bun runtime is ~45MB, plus bundled JS). `--bytecode` doesn't significantly change size but improves startup
