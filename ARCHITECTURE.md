# ChessCLI Architecture

Terminal chess application built in Gleam, compiled to JavaScript and run with Bun. Integrates with chess.com for game import, Stockfish for analysis, and generates personalized puzzles from mistakes.

## Stack

- **Language:** Gleam -> JavaScript target
- **Runtime:** Bun
- **TUI:** etch (terminal rendering, keyboard events, styling)
- **HTTP:** gleam_fetch (JS Fetch API)
- **Analysis:** Stockfish via UCI protocol over Bun.spawn

## Module Map

```
src/chesscli/
  chess/          Pure chess domain (no I/O)
  engine/         Stockfish integration (UCI protocol, FFI)
  chesscom/       Chess.com API client
  puzzle/         Puzzle generation and training
  tui/            Terminal UI views and state machine
chesscli.gleam    Entry point and event loop
config.gleam      Username persistence (~/.chesscli.json)
```

## Chess Domain (`chess/`)

Pure modules with no side effects. All game logic lives here.

| Module | Role |
|--------|------|
| `color` | White/Black type, opposite, to_string |
| `piece` | Piece/ColoredPiece types, Unicode/FEN conversion, material values |
| `square` | File/Rank/Square types, algebraic notation, 64 named constants (`square.e4`) |
| `board` | Dict(Square, ColoredPiece) sparse board, initial/empty positions |
| `position` | Full game state: board + active color + castling + en passant + clocks |
| `fen` | FEN parsing and serialization with round-trip support |
| `move` | Move type (from/to/promotion/castling/en passant), UCI encoding, move application |
| `move_gen` | Pseudo-legal and legal move generation, check/checkmate/stalemate detection |
| `san` | SAN parsing and formatting with disambiguation and check/mate suffixes |
| `pgn` | PGN parsing: tag pairs and movetext with comment/NAG/variation stripping |
| `game` | Game navigation (forward/backward/goto), free play, PGN conversion |
| `material` | Captured piece computation by board diffing, material advantage display |

## Engine Integration (`engine/`)

| Module | Role |
|--------|------|
| `uci` | Pure UCI protocol types (Score, UciInfo) and format/parse functions |
| `analysis` | MoveClassification (Best/Excellent/Good/Miss/Inaccuracy/Mistake/Blunder), MoveAnalysis, GameAnalysis, build_game_analysis |
| `stockfish` | FFI wrapper: start/evaluate/stop via Bun.spawn, multi-threaded, 256MB hash, movetime-based deep pass |

`stockfish_ffi.mjs` spawns the Stockfish process and communicates over stdin/stdout pipes. Analysis runs in two passes: a fast depth-18 pass for all positions, then a deeper movetime-based pass for positions that aren't clearly Best.

## Chess.com Integration (`chesscom/`)

| Module | Role |
|--------|------|
| `api` | Types (PlayerInfo, GameSummary), JSON decoders, display formatting |
| `client` | HTTP client: fetch_archives, fetch_games using gleam_fetch |

Public API, no auth required. Archives listed by month, games include embedded PGN.

## Puzzle Training (`puzzle/`)

| Module | Role |
|--------|------|
| `puzzle` | Puzzle type (FEN, solution/played UCI, classification), TrainingSession, PuzzlePhase (Solving/HintPiece/HintSquare/Revealed/Correct/Incorrect), progressive hints |
| `detector` | Extracts puzzles from GameAnalysis (Miss/Mistake/Blunder positions) with engine continuations |
| `store` | Persistence to ~/.chesscli/puzzles.json via FFI (up to 50 puzzles, deduped) |

## TUI Layer (`tui/`)

### State Machine (`app.gleam`)

Elm-style architecture: pure `update(state, key) -> #(state, effect)`.

**Modes:** GameReplay, FreePlay, GameBrowser, PuzzleTraining

**Input model:** All printable characters go directly to the input buffer. Escape opens a command menu (when buffer empty) or clears the buffer (when non-empty). Arrow/Home/End/PageUp/PageDown are direct-bound for navigation.

**Menu system:** Escape-triggered overlay in the right panel with mode-specific commands. Menu items vary by mode and state (e.g., "Analyze" only shown when no analysis exists).

**Effects:** Render, Quit, FetchArchives, FetchGames, AnalyzeGame, ContinueDeepAnalysis, CancelDeepAnalysis, StartPuzzles, LoadCachedPuzzles, SavePuzzles, ScanForPuzzles, RefreshPuzzles, None.

**Key types:**
```
AppState { game, mode, from_white, input_buffer, input_error, menu_open,
           browser, last_username, analysis, analysis_progress,
           deep_analysis_index, puzzle_session, puzzle_phase,
           puzzle_feedback, puzzle_hint_used, puzzle_attempted_uci }
MenuItem { key, label }
BrowserState { username, input_buffer, archives, archive_cursor,
               games, game_cursor, phase, error }
```

### Views

| Module | Role |
|--------|------|
| `board_view` | 8x8 board with RGB square colors, Unicode pieces, highlight overlays (last move, check, best move) |
| `captures_view` | Captured pieces + material advantage on rows above/below board |
| `info_panel` | Move list with SAN, move numbers, color-coded analysis classifications, fish indicator during deep analysis |
| `eval_bar` | Vertical bar with sigmoid score mapping showing position evaluation |
| `status_bar` | Mode label, side to move, input buffer display, eval score, analysis progress |
| `game_browser_view` | Username input, archive list, game list with cursor navigation |
| `puzzle_view` | Puzzle header, classification badge, hints, solution explanation |
| `menu_view` | Command menu overlay with `[key] Label` format |
| `sound` | Move/capture/check/castle sound effects via afplay FFI |
| `virtual_terminal` | Interprets etch commands into 2D text grid for snapshot testing |

### Event Loop (`chesscli.gleam`)

```
main -> render(state) -> loop(state, engine)
loop: read event -> update state -> handle effect -> loop
```

Effects are handled in the event loop: Render triggers re-draw, FetchArchives/FetchGames make HTTP calls, AnalyzeGame starts Stockfish, etc. The loop uses `flush_then_render` to discard queued key-repeat events during slow renders.

Stockfish analysis is incremental: the event loop polls for results between key events, updating progress in the status bar.

## FFI Modules

| File | Purpose |
|------|---------|
| `engine/stockfish_ffi.mjs` | Bun.spawn Stockfish process, UCI stdin/stdout communication |
| `puzzle/store_ffi.mjs` | Read/write puzzle JSON to ~/.chesscli/puzzles.json |
| `puzzle/puzzle_ffi.mjs` | Fisher-Yates shuffle for puzzle ordering |
| `tui/sound_ffi.mjs` | Spawn afplay for move sounds (embedded in binary, cwd/priv in dev) |
| `tui/eval_bar_ffi.mjs` | Math.exp for sigmoid mapping |
| `tui/tui_ffi.mjs` | process.exit and async sleep |
| `config_ffi.mjs` | Read/write username to ~/.chesscli.json |

## Testing

26 test files, 543 tests. Key patterns:
- `assert expr == expected` syntax (not gleeunit/should)
- `let assert Ok(...)` for Result unwrapping
- Snapshot tests via `virtual_terminal.render_to_string` for deterministic UI verification
- No Stockfish or network calls in tests — all pure state machine and rendering tests

## Build Pipeline

```
gleam build --target javascript
  → build/dev/javascript/chesscli/chesscli.mjs   (entry point, exports main())
  → build/dev/javascript/chesscli/**/*.mjs        (app modules + FFI)
  → build/dev/javascript/{gleam_stdlib,etch,...}/  (dependency modules)
  → build/dev/javascript/prelude.mjs              (Gleam runtime)
```

### Development

```sh
gleam run --target javascript     # Run (Bun executes compiled JS directly)
gleam test --target javascript    # Test
```

### Standalone Binary

`make` produces a ~57MB self-contained binary via `bun build --compile --bytecode`. The Makefile runs `gleam build` then bundles all modules, the Gleam runtime, and embedded assets into a single executable.

`bundle_entry.mjs` is the bundler entry point. It embeds MP3 sound files using Bun's `import ... with { type: "file" }` syntax, extracts them to a temp directory at startup (Bun's virtual `$bunfs` paths aren't accessible to external processes like `afplay`), sets `globalThis.__chesscli_sounds`, then imports and calls `main()`.

`sound_ffi.mjs` checks `globalThis.__chesscli_sounds` first (set by bundle entry in compiled mode), falling back to `cwd/priv/sound/lisp/` for development mode.

```sh
make                # Build to ./bin/chesscli
make install        # Build and copy to ~/.local/bin
make test           # Run tests
make clean          # Remove build artifacts
```

### Cross-Platform

Bun supports cross-compilation: `--target=bun-darwin-arm64`, `bun-darwin-x64`, `bun-linux-x64`, `bun-linux-arm64`. Terminal raw mode (etch) works on macOS and Linux. Windows is not supported.

### External Dependencies

- **Stockfish** — must be on PATH (`brew install stockfish` on macOS). Spawned as subprocess, not embedded (~100MB, platform-specific).
- **afplay** (macOS) — for move sounds. Ships with macOS, silently skipped if unavailable.
