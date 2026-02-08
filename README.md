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

## Keybindings

### Game Replay mode

Navigate through a loaded game's move history.

| Key | Action |
|-----|--------|
| `Left` / `Right` | Step backward / forward one move |
| `Up` / `Down` | Skip forward / backward one full turn |
| `Page Up` / `Page Down` | Skip 10 turns |
| `Home` / `End` | Jump to start / end of game |
| `f` | Flip board |
| `r` | Analyze game with Stockfish |
| `p` | Start puzzle training |
| `b` | Open Chess.com game browser |
| `q` | Quit |

### Free Play mode

Play moves freely from the current position.

| Key | Action |
|-----|--------|
| `u` | Undo last move |
| `f` | Flip board |
| `b` | Open Chess.com game browser |
| `q` | Quit |

### Move Input

Type a move in Standard Algebraic Notation (e.g. `e4`, `Nf3`, `O-O`, `exd5`, `e8=Q`).
Just start typing — any SAN character automatically enters move input mode.

| Key | Action |
|-----|--------|
| `Enter` | Submit move |
| `Escape` | Cancel input |
| `Backspace` | Delete last character |

> **Note:** The `f` and `b` keys are reserved for flip and browse, so f-file and b-file
> pawn moves (like `f4`, `b4`, `fxe5`) must be entered by pressing `/` first, then typing the move.

### Chess.com Game Browser

Press `b` from Game Replay or Free Play mode to browse games from chess.com.

1. **Enter a username** — type a chess.com username and press `Enter`
2. **Browse archives** — monthly archives are listed newest-first, use `Up`/`Down` or `j`/`k` to navigate, `Enter` to select
3. **Browse games** — games in the selected month are shown with result, opponent, rating, and time control. Press `Enter` to load a game into replay mode
4. **Press `Escape`** to go back one step, or `q` to exit the browser entirely

| Key | Action |
|-----|--------|
| `Up` / `Down` or `j` / `k` | Navigate list |
| `Enter` | Select archive or load game |
| `Escape` | Go back one step |
| `q` | Exit browser |

### Stockfish Analysis

Press `r` in Game Replay mode to analyze the current game with Stockfish. The engine evaluates every position at depth 18, and the UI updates with progress as each position is analyzed.

Once analysis completes, the following features become available:

- **Eval bar** — a vertical bar on the left side of the board showing the current position's evaluation, with white fill growing from the bottom for white advantage
- **Color-coded moves** — moves in the move list are colored by quality: green (best/excellent), cyan (miss), yellow (inaccuracy), orange (mistake), red (blunder)
- **Best move highlight** — the engine's recommended move is highlighted in blue on the board
- **Eval in status bar** — the current position's evaluation is shown in the status bar (e.g. `+0.35`, `-1.50`, `M3`)

Navigate through the game with arrow keys to see how the evaluation and best move change at each position. Loading a new game from the browser clears the analysis.

### Puzzle Training

After analyzing a game, press `p` to generate puzzles from your mistakes and practice finding the best moves. Puzzles are extracted from positions where Stockfish found a significantly better move than what was played (misses, mistakes, and blunders).

**Getting started:**

1. Load a game from chess.com (`b`) or play into a position
2. Analyze with Stockfish (`r`) — wait for analysis to complete
3. Press `p` to enter puzzle training

Each puzzle shows the board from the position where a mistake was made and asks you to find the engine's recommended move. Type your answer in SAN (e.g. `Nf7`, `d5`) or UCI (e.g. `g1f3`) and press `Enter`.

**Progressive hints:** Press `h` once to see which piece to move (e.g. "Move your knight"), press again for the target square (e.g. "Knight to f7").

**Reveal:** Press `r` to see the full solution, including what was actually played, the eval swing, and the engine's continuation line.

| Key | Action |
|-----|--------|
| Type + `Enter` | Submit answer (SAN or UCI) |
| `h` | Progressive hint (piece, then square) |
| `r` | Reveal solution with explanation |
| `n` / `Enter` | Next puzzle (after solving or revealing) |
| `N` | Previous puzzle |
| `f` | Flip board |
| `Escape` / `q` | Exit puzzle training |

Puzzles accumulate across games in `~/.chesscli/puzzles.json` (up to 50 positions). Each time you analyze a game and press `p`, new puzzles are merged with your existing collection. Duplicate positions are automatically skipped. Press `p` without analyzing to train on your saved puzzles.

## Development

```sh
gleam test --target javascript  # Run the tests
gleam build --target javascript # Build without running
```
