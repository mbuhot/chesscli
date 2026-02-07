# chesscli

A terminal chess UI written in [Gleam](https://gleam.run/), targeting JavaScript with [Bun](https://bun.sh/).

## Requirements

- [Gleam](https://gleam.run/) >= 1.0
- [Bun](https://bun.sh/) runtime

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
| `Home` / `End` | Jump to start / end of game |
| `f` | Flip board |
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

## Development

```sh
gleam test --target javascript  # Run the tests
gleam build --target javascript # Build without running
```
