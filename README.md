# chesscli

A terminal chess UI written in [Gleam](https://gleam.run/), targeting JavaScript with [Bun](https://bun.sh/).

## Requirements

- [Gleam](https://gleam.run/) >= 1.0
- [Bun](https://bun.sh/) runtime
- [Stockfish](https://stockfishchess.org/) (for game analysis — `brew install stockfish` on macOS)

## Running

```sh
gleam run --target javascript
```

## Controls

### Move Input

Type moves in Standard Algebraic Notation (e.g. `e4`, `Nf3`, `O-O`, `exd5`, `e8=Q`) directly — all letter and digit keys go straight to the input buffer with no conflicts.

| Key | Action |
|-----|--------|
| Any letter/digit | Append to move input |
| `Enter` | Submit move |
| `Backspace` | Delete last character |
| `Escape` | Clear input (if buffer non-empty) |

### Command Menu

Press `Escape` (when the input buffer is empty) to open the command menu. The menu appears as an overlay on the right panel showing available commands for the current mode. Press the shortcut key to execute a command, or `Escape` again to close.

**Game Replay** (no analysis):

| Key | Action |
|-----|--------|
| `f` | Flip board |
| `a` | Analyze game with Stockfish |
| `p` | Start puzzle training |
| `b` | Open Chess.com game browser |
| `q` | Quit |

**Game Replay** (with analysis): Same as above without `a` (already analyzed).

**Free Play**:

| Key | Action |
|-----|--------|
| `f` | Flip board |
| `u` | Undo last move |
| `p` | Start puzzle training |
| `b` | Open Chess.com game browser |
| `q` | Quit |

**Puzzle Training** (solving):

| Key | Action |
|-----|--------|
| `h` | Progressive hint (piece, then square) |
| `r` | Reveal solution |
| `f` | Flip board |
| `q` | Back to game |

**Puzzle Training** (after solving/revealing):

| Key | Action |
|-----|--------|
| `n` | Next puzzle |
| `N` | Previous puzzle |
| `f` | Flip board |
| `q` | Back to game |

### Navigation

These keys work directly without the menu in Game Replay mode:

| Key | Action |
|-----|--------|
| `Left` / `Right` | Step backward / forward one move |
| `Up` / `Down` | Skip forward / backward one full turn |
| `Page Up` / `Page Down` | Skip 10 turns |
| `Home` / `End` | Jump to start / end of game |

### Chess.com Game Browser

Open via the command menu (`Escape` > `b`).

1. **Enter a username** — type a chess.com username and press `Enter`
2. **Browse archives** — monthly archives listed newest-first, use `Up`/`Down` or `j`/`k` to navigate, `Enter` to select
3. **Browse games** — games shown with result, opponent, rating, and time control. Press `Enter` to load into replay mode
4. **Press `Escape`** to go back one step, or `q` to exit the browser

### Stockfish Analysis

Open via the command menu (`Escape` > `a`) in Game Replay mode. The engine evaluates every position at depth 18, with progress shown in the status bar.

Once analysis completes:

- **Eval bar** — vertical bar on the left showing the current position's evaluation
- **Color-coded moves** — green (best/excellent), cyan (miss), yellow (inaccuracy), orange (mistake), red (blunder)
- **Best move highlight** — engine's recommended move highlighted in blue on the board
- **Eval in status bar** — current evaluation shown (e.g. `+0.35`, `-1.50`, `M3`)

Navigate with arrow keys to see how evaluation and best move change at each position.

### Puzzle Training

After analyzing a game, open via the command menu (`Escape` > `p`) to generate puzzles from your mistakes. Puzzles are extracted from positions where Stockfish found a significantly better move.

**Getting started:**

1. Load a game from chess.com (`Escape` > `b`) or play into a position
2. Analyze with Stockfish (`Escape` > `a`) — wait for completion
3. Enter puzzle training (`Escape` > `p`)

Type your answer in SAN (e.g. `Nf7`, `d5`) or UCI (e.g. `g1f3`) and press `Enter`. Use the command menu for hints, reveal, and navigation between puzzles.

Puzzles accumulate across games in `~/.chesscli/puzzles.json` (up to 50 positions). Each analysis + `p` merges new puzzles with your collection. Duplicate positions are skipped. Press `Escape` > `p` without analyzing to train on saved puzzles.

## Development

```sh
gleam test --target javascript  # Run the tests
gleam build --target javascript # Build without running
```
