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
| `q` | Quit |

### Free Play mode

Play moves freely from the current position.

| Key | Action |
|-----|--------|
| `u` | Undo last move |
| `f` | Flip board |
| `q` | Quit |

### Move Input

Type a move in Standard Algebraic Notation (e.g. `e4`, `Nf3`, `O-O`, `exd5`, `e8=Q`).
Just start typing — any SAN character automatically enters move input mode.

| Key | Action |
|-----|--------|
| `Enter` | Submit move |
| `Escape` | Cancel input |
| `Backspace` | Delete last character |

> **Note:** The `f` key is reserved for flip, so f-file pawn moves (like `f4` or `fxe5`)
> must be entered by pressing `/` first, then typing the move.

## Development

```sh
gleam test --target javascript  # Run the tests
gleam build --target javascript # Build without running
```
