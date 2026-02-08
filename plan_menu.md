# Menu System Design

## Context

Single-key shortcuts (`f`=flip, `r`=analyze/reveal, `q`=quit, `b`=browse, `h`=hint) conflict with chess SAN notation (f-file, Rook, Queen, b-file, h-file). This forces workarounds: the b-file is excluded from auto-input, and users must press `/` before typing f-file or b-file moves. In puzzle mode, keys like `h`, `r`, `q` have dual behavior depending on whether the input buffer is empty. This is confusing and breaks flow when solving puzzles.

**Goal**: All letter/digit keys go directly to move input. Commands are accessed via an explicit menu opened with a dedicated key.

## Key Design Decisions

**Menu key: `Escape`** — In the current system, Escape does nothing in GameReplay mode and is underused elsewhere. It's the universal "bring up a menu / back out" key. Arrow keys, Home, End, PageUp, PageDown remain direct-bound (they never conflict with SAN).

**MoveInput mode is removed** — GameReplay and FreePlay handle character input directly. All printable characters append to `input_buffer`. Enter submits, Backspace deletes, Escape (when buffer non-empty) clears the buffer. Escape (when buffer empty) opens the menu.

**Menu overlay** — When open, the menu replaces the right-side panel (info_panel or puzzle_view area at col 34+). Shows mode-specific commands with `[key]` labels. Pressing the shortcut key executes the command and closes the menu. Pressing Escape again closes the menu.

## Mode Behavior Summary

### GameReplay / FreePlay
| Key | Action |
|-----|--------|
| Arrow keys, Home, End, PgUp, PgDn | Direct navigation (unchanged) |
| Any printable char | Append to move input buffer |
| Enter | Submit move (if buffer non-empty) |
| Backspace | Delete last char from buffer |
| Escape (buffer non-empty) | Clear input buffer |
| Escape (buffer empty) | Open command menu |

### PuzzleTraining — Solving phase
| Key | Action |
|-----|--------|
| Any printable char | Append to move input buffer |
| Enter | Check puzzle answer |
| Backspace | Delete last char |
| Escape (buffer non-empty) | Clear buffer |
| Escape (buffer empty) | Open command menu |

### PuzzleTraining — After result (Correct/Revealed/Incorrect)
| Key | Action |
|-----|--------|
| Enter | Next puzzle |
| Escape | Open command menu |

### Menu (all modes)
| Key | Action |
|-----|--------|
| Escape | Close menu |
| Shortcut key | Execute command, close menu |

## Menu Items by Mode

**GameReplay** (no analysis):
```
 Commands          Esc: close
 [f] Flip board
 [a] Analyze game
 [p] Puzzle training
 [b] Browse chess.com
 [q] Quit
```

**GameReplay** (with analysis):
```
 Commands          Esc: close
 [f] Flip board
 [p] Puzzle training
 [b] Browse chess.com
 [q] Quit
```

**FreePlay**:
```
 Commands          Esc: close
 [f] Flip board
 [u] Undo move
 [p] Puzzle training
 [b] Browse chess.com
 [q] Quit
```

**PuzzleTraining — Solving/HintPiece/HintSquare/Incorrect**:
```
 Commands          Esc: close
 [h] Hint
 [r] Reveal solution
 [f] Flip board
 [q] Back to game
```

**PuzzleTraining — Correct**:
```
 Commands          Esc: close
 [n] Next puzzle
 [N] Previous puzzle
 [r] View full line
 [f] Flip board
 [q] Back to game
```

**PuzzleTraining — Revealed**:
```
 Commands          Esc: close
 [n] Next puzzle
 [N] Previous puzzle
 [f] Flip board
 [q] Back to game
```

**GameBrowser**: Left unchanged — it has its own navigation model and no SAN conflicts.

## Changes to `r` shortcut

Rename the analysis shortcut from `r` to `a` (for "Analyze") to avoid confusion with the puzzle `r` (reveal). This makes the menu more intuitive.

## Files to Modify

### `src/chesscli/tui/app.gleam` (major changes)
- Remove `MoveInput` from `Mode` type
- Add `menu_open: Bool` to `AppState`
- Add `MenuItem` type and `menu_items(state) -> List(MenuItem)` function
- Add `update_menu` handler
- Refactor `update_game_replay`: remove single-key shortcuts, all chars -> buffer, Escape -> menu
- Refactor `update_free_play`: same pattern
- Refactor `update_puzzle_solving`: remove buffer-empty checks for h/r/q, all chars -> buffer, Escape -> menu
- Refactor `update_puzzle_after_result`: Enter -> next, Escape -> menu, remove direct n/N/r/q
- Remove `update_move_input`, `enter_move_input`, `try_auto_input`, `is_san_char`, `prev_mode_from_game`
- `apply_input_move` stays but returns to the correct mode (GameReplay if cursor < total moves, FreePlay otherwise)

### `src/chesscli/tui/menu_view.gleam` (new file)
- Render menu items at col 34+ with `[key] Label` format
- Header line "Commands" with "Esc: close"
- Highlight shortcut key with color (cyan bold)

### `src/chesscli/tui/status_bar.gleam`
- Remove MoveInput case (mode no longer exists)
- When `input_buffer != ""`: show `> buffer_cursor`
- When `input_buffer == ""`: show mode + side + "Esc: menu"
- Remove verbose key listings (now in menu)

### `src/chesscli.gleam`
- Update render functions: when `menu_open`, render `menu_view` instead of `info_panel`/`puzzle_view`
- Remove import of `MoveInput` mode

### `test/chesscli/app_test.gleam`
- Update all tests that use single-key shortcuts to go through menu (Esc then key)
- Remove MoveInput-specific tests; replace with buffer-in-mode tests
- Add menu open/close tests
- Add menu command execution tests

### `test/chesscli/snapshot_test.gleam`
- Update status bar text in all snapshots
- Add menu overlay snapshot test

## Implementation Order

1. Add `menu_open` field and `MenuItem` type to `app.gleam`
2. Create `tui/menu_view.gleam` with render function
3. Add `menu_items` and `update_menu` to `app.gleam`
4. Refactor `update_game_replay` — remove shortcuts, add buffer handling + Escape menu
5. Remove `MoveInput` mode and related functions
6. Refactor `update_free_play` — same pattern
7. Refactor `update_puzzle_solving` — all chars to buffer, Escape menu
8. Refactor `update_puzzle_after_result` — Enter next, Escape menu
9. Update `status_bar.gleam` — remove MoveInput, show buffer inline
10. Update `chesscli.gleam` — menu overlay rendering
11. Update tests (app_test, snapshot_test)
12. Run all tests, fix any failures
