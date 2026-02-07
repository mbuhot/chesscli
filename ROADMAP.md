# ChessCLI Project Roadmap

Terminal chess application built in Gleam (compiled to JavaScript, bundled with Bun) that integrates with chess.com to review game history, display an interactive chessboard with a TUI, and generate personalized puzzles from game mistakes/blunders.

Key constraint: Chess.com's public API does NOT expose game review data (mistakes, blunders, accuracy). It only provides game archives with PGN data. To detect blunders and generate puzzles, we run our own analysis using local Stockfish via the UCI protocol.

Target: Gleam -> JavaScript -> Bun single binary (`bun build --compile`)

## Dependencies

All JS-target compatible:

| Package | Purpose | JS Target |
|---------|---------|-----------|
| etch | TUI rendering, keyboard/mouse events, styling | Yes |
| gleam_json | JSON encoding/decoding | Yes |
| gleam_http | HTTP request/response types | Yes |
| gleam_fetch | HTTP client using JS Fetch API | Yes (replaces erlang-only gleam_httpc) |
| gleeunit | Testing | Yes (dev dep) |

Not using (erlang-only): gleam_httpc, gleam_otp, gleam_erlang, gleam_erlexec, gchess

## Architecture

```
src/chesscli/
  chess/          -- Core chess domain (types, FEN, moves, PGN)
  tui/            -- Terminal UI (etch-based rendering, input, event loop)
  chesscom/       -- Chess.com API client (HTTP, JSON decoding)
  engine/         -- Stockfish integration (UCI protocol, Bun.spawn FFI)
  puzzle/         -- Puzzle generation from blunders, training mode
```

## Phase Summary

| Phase | Status | Description |
|-------|--------|-------------|
| 1 | DONE | Chess board fundamentals (types, FEN, board rendering) |
| 2 | DONE | Move logic, SAN/PGN parsing, game navigation |
| 3 | DONE | Interactive TUI (app state machine, highlights, panels, keybindings) |
| 3.5 | DONE | Captured pieces & material advantage display |
| 4 | DONE | Chess.com integration (API client, game browser) |
| 5 | TODO | Stockfish analysis (UCI protocol, eval, blunder detection) |
| 6 | TODO | Puzzle generation & training from blunders |

---

## Phase 1: Chess Board Fundamentals (DONE)

**Goal:** Parse FEN strings, render a chessboard in the terminal.
**Delivers:** `gleam run --target javascript` shows a rendered starting position.
**Dep:** `gleam add etch`

### Module: `chess/color.gleam`

```gleam
pub type Color { White  Black }
pub fn opposite(color: Color) -> Color
pub fn to_string(color: Color) -> String
```

### Module: `chess/piece.gleam`

```gleam
pub type Piece { King  Queen  Rook  Bishop  Knight  Pawn }

pub type ColoredPiece {
  ColoredPiece(color: Color, piece: Piece)
}

pub fn to_unicode(cp: ColoredPiece) -> String
pub fn to_fen_char(cp: ColoredPiece) -> String
pub fn from_fen_char(char: String) -> Result(ColoredPiece, Nil)
pub fn value(p: Piece) -> Int  // Q=9, R=5, B=3, N=3, P=1, K=0
```

### Module: `chess/square.gleam`

```gleam
pub type File { A  B  C  D  E  F  G  H }
pub type Rank { R1  R2  R3  R4  R5  R6  R7  R8 }
pub type Square { Square(file: File, rank: Rank) }

pub fn to_string(sq: Square) -> String        // Square(E, R4) -> "e4"
pub fn from_string(s: String) -> Result(Square, Nil)
pub fn to_index(sq: Square) -> Int             // 0-63 (a1=0, b1=1, ..., h8=63)
pub fn from_index(i: Int) -> Result(Square, Nil)
```

64 named constants: `square.e4`, `square.a1`, etc.

### Module: `chess/board.gleam`

Dict(Square, ColoredPiece) — simple, readable, sufficient for a TUI app.

```gleam
pub type Board { Board(pieces: Dict(Square, ColoredPiece)) }

pub fn empty() -> Board
pub fn initial() -> Board
pub fn get(board: Board, sq: Square) -> Option(ColoredPiece)
pub fn set(board: Board, sq: Square, piece: ColoredPiece) -> Board
pub fn remove(board: Board, sq: Square) -> Board
```

### Module: `chess/position.gleam`

```gleam
pub type CastlingRights {
  CastlingRights(
    white_kingside: Bool, white_queenside: Bool,
    black_kingside: Bool, black_queenside: Bool,
  )
}

pub type Position {
  Position(
    board: Board, active_color: Color, castling: CastlingRights,
    en_passant: Option(Square), halfmove_clock: Int, fullmove_number: Int,
  )
}
```

### Module: `chess/fen.gleam`

```gleam
pub fn parse(fen: String) -> Result(Position, FenError)
pub fn to_string(pos: Position) -> String
```

Key test cases: starting position, after 1.e4, round-trip parse/to_string.

### Module: `tui/board_view.gleam`

Render with etch using absolute positioning, RGB background colors, Unicode pieces.
Each square: 3 chars wide. Chess.com green color scheme. Perspective flip with `f` key.

---

## Phase 2: Move Logic & PGN Parsing (DONE)

**Goal:** Legal move generation and PGN parsing to load/replay full games.
**Delivers:** Load a PGN, step through moves forward/backward.

### Module: `chess/move.gleam`

```gleam
pub type Move {
  Move(from: Square, to: Square, promotion: Option(Piece),
       is_castling: Bool, is_en_passant: Bool)
}

pub fn to_uci(move: Move) -> String          // "e2e4", "e7e8q"
pub fn from_uci(s: String) -> Result(Move, Nil)
```

### Module: `chess/move_gen.gleam`

Build incrementally by piece type:
1. Pawn moves: single push, double push, captures, en passant, promotion
2. Knight moves: L-shaped jumps (up to 8 targets)
3. Bishop moves: diagonal rays until blocked
4. Rook moves: file/rank rays until blocked
5. Queen moves: bishop + rook combined
6. King moves: one square any direction + castling

Then: check detection, legal filtering (discard moves leaving king in check), game status.

```gleam
pub fn legal_moves(pos: Position) -> List(Move)
pub fn is_in_check(pos: Position, color: Color) -> Bool
pub fn game_status(pos: Position) -> GameStatus

pub type GameStatus { InProgress  Checkmate  Stalemate  Draw }
```

Perft validation: Depth 1: 20, Depth 2: 400, Depth 3: 8,902, Depth 4: 197,281

### Module: `chess/san.gleam`

SAN parsing requires the current position for disambiguation.

```gleam
pub fn parse(san: String, pos: Position) -> Result(Move, SanError)
pub fn to_string(move: Move, pos: Position) -> String
```

Patterns: pawn push, piece move, capture, disambiguation (file/rank/both), castling, promotion, check/mate suffix.

### Module: `chess/pgn.gleam`

```gleam
pub type PgnGame {
  PgnGame(tags: Dict(String, String), moves: List(Move), positions: List(Position))
}

pub fn parse(pgn: String) -> Result(PgnGame, PgnError)
```

Parsing: split tags/movetext, parse [Key "Value"] tags, strip comments/NAGs/variations, parse SAN tokens.

### Module: `chess/game.gleam`

```gleam
pub type Game {
  Game(tags: Dict(String, String), positions: List(Position),
       moves: List(Move), current_index: Int)
}

pub fn from_pgn(pgn: PgnGame) -> Game
pub fn current_position(game: Game) -> Position
pub fn forward(game: Game) -> Result(Game, Nil)
pub fn backward(game: Game) -> Result(Game, Nil)
pub fn goto_start(game: Game) -> Game
pub fn goto_end(game: Game) -> Game
pub fn apply_move(game: Game, move: Move) -> Result(Game, MoveError)
```

---

## Phase 3: Interactive TUI (DONE)

**Goal:** Full terminal UI with keyboard navigation and algebraic notation input.
**Delivers:** Arrow keys step through a game, type moves like "e4" to play.

### Module: `tui/app.gleam`

```gleam
pub type Mode { GameReplay  FreePlay  MoveInput  GameBrowser }

pub type AppState {
  AppState(game: Game, mode: Mode, from_white: Bool,
           input_buffer: String, input_error: String)
}
```

Event loop: enter raw mode + alternate screen -> read event -> update state -> render -> repeat.

### Keyboard Bindings

GameReplay: Left/Right step, Home/End jump, f flip, q quit, / or SAN char enters MoveInput
FreePlay: u undo, f flip, q quit, / or SAN char enters MoveInput
MoveInput: chars build buffer, Enter apply, Escape cancel, Backspace delete

### Board View Enhancements
- Last move highlight: from/to squares with distinct background
- Check highlight: king's square in red
- Info panel: move list with SAN and current-move cursor
- Status bar: mode-aware keybinding hints

### Phase 3.5: Captured Pieces & Material (DONE)

- `chess/material.gleam` — diff board vs starting material, format captures
- `tui/captures_view.gleam` — render on rows 0 and 12
- Pieces sorted ascending by value (P, B, N, R, Q), `+N` advantage suffix

---

## Phase 4: Chess.com Integration

**Goal:** Fetch and browse game history from chess.com.
**Delivers:** Enter username, browse games by month, select and replay any game.
**Deps:** `gleam add gleam_json gleam_http gleam_fetch`

### Chess.com API (public, no auth)

Base URL: `https://api.chess.com/pub`

| Endpoint | Returns |
|----------|---------|
| `/player/{username}` | Player profile info |
| `/player/{username}/games/archives` | List of monthly archive URLs |
| `/player/{username}/games/{YYYY}/{MM}` | Games for a month (JSON with embedded PGN) |
| `/player/{username}/games/{YYYY}/{MM}/pgn` | Raw multi-game PGN text |

Rate limiting: max 2-3 concurrent requests. Sequential is fine. At 90% daily limit, 50% return 429.

### Module: `chesscom/types.gleam`

```gleam
pub type GameSummary {
  GameSummary(
    url: String, pgn: String, time_class: String, time_control: String,
    rated: Bool, white: PlayerResult, black: PlayerResult,
    end_time: Int, accuracies: Option(Accuracies),
  )
}

pub type PlayerResult {
  PlayerResult(username: String, rating: Int, result: String)
  // result: "win", "resigned", "timeout", "checkmated", "stalemate", etc.
}

pub type Accuracies {
  Accuracies(white: Float, black: Float)
}
```

### Module: `chesscom/api.gleam`

```gleam
pub fn fetch_archives(username: String) -> Promise(Result(List(String), ApiError))
pub fn fetch_monthly_games(username: String, year: Int, month: Int) -> Promise(Result(List(GameSummary), ApiError))
```

Note: `gleam_fetch` returns promises (async JS). Need to integrate with TUI event loop.

### GameBrowser Mode
- Username input prompt at startup or via command
- List months with game counts (most recent first)
- List games in selected month: opponent, result, time control, rating
- j/k or arrow keys to scroll, Enter to select and load game
- Cache responses in memory for the session

---

## Phase 5: Stockfish Analysis

**Goal:** Evaluate positions and detect blunders using local Stockfish.
**Delivers:** Per-move evaluation bars, color-coded move quality, best-move suggestions.
**Requires:** Stockfish installed locally (`brew install stockfish`)

### UCI Protocol: `engine/uci.gleam`

UCI is a text-based protocol over stdin/stdout.

Commands we send:
```
uci                           -> responds "uciok"
isready                       -> responds "readyok"
ucinewgame                    -> reset for new game
position fen <fen>            -> set position
position fen <fen> moves e2e4 e7e5  -> set position with moves
go depth 18                   -> analyze to depth 18
stop                          -> stop analysis
quit                          -> shutdown engine
```

Responses we parse:
```
info depth 18 score cp 35 nodes 1234567 nps 2000000 pv e2e4 e7e5 g1f3
info depth 18 score mate 3 ...
bestmove e2e4 ponder e7e5
```

```gleam
pub type Score {
  Centipawns(Int)    // +100 = white up one pawn
  Mate(Int)          // Mate in N (negative = getting mated)
}

pub type UciInfo {
  UciInfo(depth: Int, score: Score, pv: List(String), nodes: Int)
}

pub fn format_position(fen: String, moves: List(String)) -> String
pub fn format_go(depth: Int) -> String
pub fn parse_info(line: String) -> Option(UciInfo)
pub fn parse_bestmove(line: String) -> Option(#(String, Option(String)))
```

### Stockfish Process: `engine/stockfish.gleam`

Spawn via Bun FFI:

```javascript
// src/chesscli/engine/stockfish_ffi.mjs
import { spawn } from "bun";

export function start_stockfish() {
  const proc = spawn(["stockfish"], {
    stdin: "pipe", stdout: "pipe", stderr: "pipe",
  });
  return proc;
}

export function send_command(proc, command) {
  proc.stdin.write(command + "\n");
}
```

```gleam
@external(javascript, "../engine/stockfish_ffi.mjs", "start_stockfish")
fn do_start() -> StockfishProcess

pub fn evaluate(engine, fen: String, depth: Int) -> Result(Evaluation, EngineError)
// 1. Send "position fen <fen>"
// 2. Send "go depth <depth>"
// 3. Collect info lines until "bestmove"
// 4. Return last info's score + bestmove
```

### Game Analysis: `engine/analysis.gleam`

```gleam
pub type MoveClassification {
  Best          // Matches engine top choice
  Excellent     // < 0.1 pawn loss
  Good          // < 0.3 pawn loss
  Inaccuracy    // 0.3 - 1.0 pawn loss
  Mistake       // 1.0 - 2.0 pawn loss
  Blunder       // > 2.0 pawn loss
}

pub type MoveAnalysis {
  MoveAnalysis(
    move_number: Int, move_san: String, eval_before: Score,
    eval_after: Score, best_move: String, classification: MoveClassification,
  )
}

pub fn analyze_game(engine, game: Game, depth: Int) -> List(MoveAnalysis)
pub fn classify_eval_change(before: Score, after: Score, color: Color) -> MoveClassification
```

Classification: compare eval swing from the player's perspective.
- White plays, eval +1.0 to -0.5 = 1.5 pawn swing = Mistake
- White plays, eval +1.0 to -2.0 = 3.0 pawn swing = Blunder

### UI Additions
- Eval bar: vertical bar on left side of board, white/black gradient showing advantage
- Move list colors: Green (best/excellent), Yellow (inaccuracy), Orange (mistake), Red (blunder)
- Status bar: current position eval (+0.35, M3)
- Best move overlay: arrow or highlight showing engine's recommended move

---

## Phase 6: Puzzle Generation & Training

**Goal:** Convert blunders into personalized puzzles with interactive solving.
**Delivers:** After game analysis, solve puzzles from your own blunders.

### Blunder Detection: `puzzle/detector.gleam`

```gleam
pub fn find_puzzles(analysis: List(MoveAnalysis), game: Game) -> List(Puzzle)
// For each Mistake/Blunder:
// - Position = position BEFORE the bad move
// - Player color = who made the mistake
// - Solution = engine's best move (and possibly continuation)
// - Can extend to multi-move: if best response is forced, include follow-up
```

### Module: `puzzle/puzzle.gleam`

```gleam
pub type Puzzle {
  Puzzle(
    position: Position, player_color: Color, solution: List(Move),
    source_game: Option(String), theme: String,
  )
}

pub type PuzzleResult { Solved  Failed  Abandoned }
```

### Module: `puzzle/trainer.gleam`

```gleam
pub type TrainerState {
  TrainerState(puzzles: List(Puzzle), current_index: Int,
               score: Int, total_attempted: Int)
}

pub fn start_session(puzzles: List(Puzzle)) -> TrainerState
pub fn check_move(state: TrainerState, move: Move) -> #(Bool, TrainerState)
pub fn next_puzzle(state: TrainerState) -> Result(#(Puzzle, TrainerState), Nil)
```

### Puzzle UI Mode
- Show position with "Find the best move for White/Black"
- Player enters move via algebraic notation
- Correct: play opponent's response, continue sequence
- Wrong: "Not the best move. Try again?" or "Show solution"
- After solving: show evaluation explanation, move to next puzzle
- Session summary: X/Y solved, common themes

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Move generation correctness (hardest part) | Perft testing at each depth, build incrementally by piece type |
| Etch JS target maturity | Test early in Phase 1; fallback to raw ANSI escape codes if needed |
| Bun.spawn FFI for Stockfish | Prototype the FFI early in Phase 5; text-based UCI protocol is simple |
| chess.com API changes (undocumented) | Wrap in Result types, PGN endpoint is most stable |
| Terminal compatibility (Unicode/RGB) | Consider ASCII fallback mode, 16-color fallback |
| gleam_fetch async/promises | Need to integrate promise-based API with synchronous TUI event loop |

## Build & Binary

- Dev: `gleam run --target javascript`
- Test: `gleam test --target javascript`
- Binary: `gleam build --target javascript && bun build --compile build/dev/javascript/chesscli/chesscli.mjs --outfile chesscli`

## Verification

- Phase 1: FEN round-trips, visual board rendering
- Phase 2: Perft (20/400/8902), PGN parsing, SAN disambiguation
- Phase 3: Interactive keyboard nav, move input, mode switching
- Phase 4: Fetch real chess.com games, browse and replay
- Phase 5: Analyze a known game with Stockfish, verify classifications
- Phase 6: Generate and solve puzzles from analyzed games
