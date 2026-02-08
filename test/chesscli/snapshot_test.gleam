import chesscli/chess/color
import chesscli/chess/fen
import chesscli/chess/game
import chesscli/chess/move_gen
import chesscli/chess/pgn
import chesscli/chess/square
import chesscli/engine/analysis.{Best, GameAnalysis, Mistake, MoveAnalysis}
import chesscli/engine/uci.{Centipawns}
import chesscli/puzzle/puzzle.{Puzzle}
import chesscli/tui/app.{type AppState, AppState, GameBrowser, PuzzleTraining}
import chesscli/tui/board_view.{RenderOptions}
import chesscli/tui/captures_view
import chesscli/tui/eval_bar
import chesscli/tui/game_browser_view
import chesscli/tui/info_panel
import chesscli/tui/puzzle_view
import chesscli/tui/status_bar
import chesscli/tui/virtual_terminal
import etch/command
import etch/event
import etch/style
import gleam/list
import gleam/dict
import gleam/option.{None, Some}
import gleam/string

// --- virtual_terminal basic tests ---

pub fn render_empty_grid_test() {
  let result = virtual_terminal.render_to_string([], 10, 2)
  assert result == "\n"
}

pub fn render_move_to_and_print_test() {
  let commands = [command.MoveTo(0, 0), command.Print("Hi")]
  let result = virtual_terminal.render_to_string(commands, 10, 1)
  assert result == "Hi"
}

pub fn render_multiple_prints_test() {
  let commands = [
    command.MoveTo(0, 0),
    command.Print("AB"),
    command.MoveTo(5, 0),
    command.Print("CD"),
  ]
  let result = virtual_terminal.render_to_string(commands, 10, 1)
  assert result == "AB   CD"
}

pub fn render_multiline_test() {
  let commands = [
    command.MoveTo(0, 0),
    command.Print("Row0"),
    command.MoveTo(0, 1),
    command.Print("Row1"),
  ]
  let result = virtual_terminal.render_to_string(commands, 10, 2)
  assert result == "Row0\nRow1"
}

pub fn render_ignores_style_commands_test() {
  let commands = [
    command.MoveTo(0, 0),
    command.SetBackgroundColor(style.Rgb(255, 0, 0)),
    command.Print("X"),
    command.ResetStyle,
  ]
  let result = virtual_terminal.render_to_string(commands, 5, 1)
  assert result == "X"
}

// --- Full UI snapshot: initial board (FreePlay mode) ---

pub fn initial_board_snapshot_test() {
  let state = app.new()
  let result = render_snapshot(state)
  assert result
    == "
      ┌────────────────────────┐
    8 │ ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ │
    7 │ ♟  ♟  ♟  ♟  ♟  ♟  ♟  ♟ │
    6 │                        │
    5 │                        │
    4 │                        │
    3 │                        │
    2 │ ♟  ♟  ♟  ♟  ♟  ♟  ♟  ♟ │
    1 │ ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ │
      └────────────────────────┘
        a  b  c  d  e  f  g  h

  [PLAY] White | u:undo f:flip q:quit
"
}

// --- Snapshot after 1. e4 in FreePlay ---

pub fn after_e4_snapshot_test() {
  let state = app.new()
  let #(state, _) = app.update(state, event.Char("e"))
  let #(state, _) = app.update(state, event.Char("4"))
  let #(state, _) = app.update(state, event.Char("\r"))
  let result = render_snapshot(state)
  assert result
    == "
      ┌────────────────────────┐  >1. e4
    8 │ ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ │
    7 │ ♟  ♟  ♟  ♟  ♟  ♟  ♟  ♟ │
    6 │                        │
    5 │                        │
    4 │             ♟          │
    3 │                        │
    2 │ ♟  ♟  ♟  ♟     ♟  ♟  ♟ │
    1 │ ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ │
      └────────────────────────┘
        a  b  c  d  e  f  g  h

  [PLAY] Black | u:undo f:flip q:quit
"
}

// --- Snapshot: GameReplay mode with PGN ---

pub fn replay_mode_snapshot_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3")
  let g = game.from_pgn(pgn_game)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let state = AppState(..app.from_game(g), game: g)
  let result = render_snapshot(state)
  assert result
    == "
      ┌────────────────────────┐  >1. e4     e5
    8 │ ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ │   2. Nf3
    7 │ ♟  ♟  ♟  ♟     ♟  ♟  ♟ │
    6 │                        │
    5 │             ♟          │
    4 │             ♟          │
    3 │                        │
    2 │ ♟  ♟  ♟  ♟     ♟  ♟  ♟ │
    1 │ ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ │
      └────────────────────────┘
        a  b  c  d  e  f  g  h

  [REPLAY] White | ←→ Home End f r q
"
}

// --- Snapshot: captures display after 1. e4 d5 2. exd5 ---

pub fn captures_after_exchange_snapshot_test() {
  let state = app.new()
  // 1. e4
  let #(state, _) = app.update(state, event.Char("e"))
  let #(state, _) = app.update(state, event.Char("4"))
  let #(state, _) = app.update(state, event.Char("\r"))
  // 1... d5
  let #(state, _) = app.update(state, event.Char("d"))
  let #(state, _) = app.update(state, event.Char("5"))
  let #(state, _) = app.update(state, event.Char("\r"))
  // 2. exd5
  let #(state, _) = app.update(state, event.Char("e"))
  let #(state, _) = app.update(state, event.Char("x"))
  let #(state, _) = app.update(state, event.Char("d"))
  let #(state, _) = app.update(state, event.Char("5"))
  let #(state, _) = app.update(state, event.Char("\r"))
  let result = render_snapshot(state)
  assert result
    == "
      ┌────────────────────────┐   1. e4     d5
    8 │ ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ │  >2. exd5
    7 │ ♟  ♟  ♟     ♟  ♟  ♟  ♟ │
    6 │                        │
    5 │          ♟             │
    4 │                        │
    3 │                        │
    2 │ ♟  ♟  ♟  ♟     ♟  ♟  ♟ │
    1 │ ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ │
      └────────────────────────┘
        a  b  c  d  e  f  g  h
       ♟ +1
  [PLAY] Black | u:undo f:flip q:quit
"
}

// --- Snapshot: long game with scroll ---

pub fn long_game_replay_snapshot_test() {
  let pgn_str =
    "[White \"player1\"]
[Black \"player2\"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7 11. Nbd2 Bb7 12. Bc2 Re8"
  let assert Ok(pgn_game) = pgn.parse(pgn_str)
  let g = game.from_pgn(pgn_game)
  // Go to move 16 (8. c3) — middle of the game
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let state = AppState(..app.from_game(g), game: g)
  let result = render_long_snapshot(state)
  assert result
    == "       player2
      ┌────────────────────────┐    3. Bb5   a6
    8 │ ♜     ♝  ♛     ♜  ♚    │    4. Ba4   Nf6
    7 │       ♟     ♝  ♟  ♟  ♟ │    5. O-O   Be7
    6 │ ♟     ♞  ♟     ♞       │    6. Re1   b5
    5 │    ♟        ♟          │    7. Bb3   d6
    4 │             ♟          │  > 8. c3    O-O
    3 │    ♝  ♟        ♞       │    9. h3    Nb8
    2 │ ♟  ♟     ♟     ♟  ♟  ♟ │   10. d4    Nbd7
    1 │ ♜  ♞  ♝  ♛  ♜     ♚    │   11. Nbd2  Bb7
      └────────────────────────┘   12. Bc2   Re8
        a  b  c  d  e  f  g  h
       player1
  [REPLAY] White | ←→ Home End f r q
"
}

fn render_long_snapshot(state: app.AppState) -> String {
  let commands = render_full_ui(state)
  virtual_terminal.render_to_string(commands, 55, 15)
}

// --- Snapshot: browser username input ---

pub fn browser_username_input_snapshot_test() {
  let state = app.new()
  let #(state, _) = app.update(state, event.Char("b"))
  let #(state, _) = app.update(state, event.Char("h"))
  let #(state, _) = app.update(state, event.Char("i"))
  let #(state, _) = app.update(state, event.Char("k"))
  let result = render_snapshot(state)
  assert result
    == "
  Chess.com username: hik\u{2588}











  [BROWSE] Enter username | Esc:back
"
}

// --- Snapshot: replay with analysis shows eval bar and eval in status ---

pub fn replay_with_analysis_snapshot_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3")
  let g = game.from_pgn(pgn_game)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let ga =
    GameAnalysis(
      evaluations: [Centipawns(0), Centipawns(35), Centipawns(20), Centipawns(45)],
      move_analyses: [
        MoveAnalysis(0, Centipawns(0), Centipawns(35), "e2e4", [], Best),
        MoveAnalysis(1, Centipawns(35), Centipawns(20), "e7e5", [], Best),
        MoveAnalysis(2, Centipawns(20), Centipawns(45), "g1f3", [], Best),
      ],
    )
  let state = AppState(..app.from_game(g), game: g, analysis: Some(ga))
  let result = render_snapshot(state)
  // Eval bar appears at columns 0-1 on rows 2-9 (8 rows).
  // At +0.20 (position after e5), bar is slightly white-biased.
  // Status bar should show eval "+0.20".
  // The current position eval bar label appears at row 6 (midpoint of rows 2-9).
  // Eval bar at col 0-1 overwrites rank labels; "+0" label at midpoint row
  assert result
    == "
      ┌────────────────────────┐  >1. e4     e5
    8 │ ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ │   2. Nf3
    7 │ ♟  ♟  ♟  ♟     ♟  ♟  ♟ │
    6 │                        │
    5 │             ♟          │
+0  4 │             ♟          │
    3 │                        │
    2 │ ♟  ♟  ♟  ♟     ♟  ♟  ♟ │
    1 │ ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ │
      └────────────────────────┘
        a  b  c  d  e  f  g  h

  [REPLAY] White | +0.20 | ←→ Home End f q
"
}

// --- Snapshot: fish indicator during deep analysis ---

pub fn deep_analysis_white_move_fish_snapshot_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3")
  let g = game.from_pgn(pgn_game)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  // deep_analysis_index 0 = analyzing white's first move (e4)
  let state = AppState(..app.from_game(g), game: g, deep_analysis_index: Some(0))
  let result = render_snapshot(state)
  // Fish appears in padding between white and black moves, replacing 2 spaces
  assert result
    == "
      ┌────────────────────────┐  >1. e4   🐟e5
    8 │ ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ │   2. Nf3
    7 │ ♟  ♟  ♟  ♟     ♟  ♟  ♟ │
    6 │                        │
    5 │             ♟          │
    4 │             ♟          │
    3 │                        │
    2 │ ♟  ♟  ♟  ♟     ♟  ♟  ♟ │
    1 │ ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ │
      └────────────────────────┘
        a  b  c  d  e  f  g  h

  [REPLAY] White | ←→ Home End f r q
"
}

pub fn deep_analysis_black_move_fish_snapshot_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3")
  let g = game.from_pgn(pgn_game)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  // deep_analysis_index 1 = analyzing black's first move (e5)
  let state = AppState(..app.from_game(g), game: g, deep_analysis_index: Some(1))
  let result = render_snapshot(state)
  // Fish appears after the black move text
  assert result
    == "
      ┌────────────────────────┐  >1. e4     e5🐟
    8 │ ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ │   2. Nf3
    7 │ ♟  ♟  ♟  ♟     ♟  ♟  ♟ │
    6 │                        │
    5 │             ♟          │
    4 │             ♟          │
    3 │                        │
    2 │ ♟  ♟  ♟  ♟     ♟  ♟  ♟ │
    1 │ ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ │
      └────────────────────────┘
        a  b  c  d  e  f  g  h

  [REPLAY] White | ←→ Home End f r q
"
}

// --- Puzzle snapshots ---

fn puzzle_snapshot_state() -> AppState {
  let p =
    Puzzle(
      fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
      player_color: color.Black,
      solution_uci: "d7d5",
      played_uci: "e7e5",
      continuation: ["d7d5", "e4d5", "d8d5"],
      eval_before: "+0.2",
      eval_after: "+1.7",
      source_label: "Alice vs Bob",
      classification: Mistake,
      white_name: "Alice",
      black_name: "Bob",
      solve_count: 0,
    )
  let session = puzzle.new_session([p])
  app.enter_puzzle_mode(app.from_game(game.new()), session)
}

pub fn puzzle_solving_snapshot_test() {
  let state = puzzle_snapshot_state()
  let result = render_puzzle_snapshot(state)
  assert result
    == "
      ┌────────────────────────┐  Puzzle 1/1  Mistake
    1 │ ♜  ♞  ♝  ♚  ♛  ♝  ♞  ♜ │  Find the best move for Black
    2 │ ♟  ♟  ♟     ♟  ♟  ♟  ♟ │
    3 │                        │
    4 │          ♟             │
    5 │                        │
    6 │                        │
    7 │ ♟  ♟  ♟  ♟  ♟  ♟  ♟  ♟ │
    8 │ ♜  ♞  ♝  ♚  ♛  ♝  ♞  ♜ │
      └────────────────────────┘
        h  g  f  e  d  c  b  a

  Black | h:hint r:reveal n:next Esc:back q:quit
"
}

pub fn puzzle_hint_piece_snapshot_test() {
  let state = puzzle_snapshot_state()
  let #(state, _) = app.update(state, event.Char("h"))
  let result = render_puzzle_snapshot(state)
  assert result
    == "
      ┌────────────────────────┐  Puzzle 1/1  Mistake
    1 │ ♜  ♞  ♝  ♚  ♛  ♝  ♞  ♜ │  Find the best move for Black
    2 │ ♟  ♟  ♟     ♟  ♟  ♟  ♟ │
    3 │                        │
    4 │          ♟             │  Move your pawn
    5 │                        │
    6 │                        │
    7 │ ♟  ♟  ♟  ♟  ♟  ♟  ♟  ♟ │
    8 │ ♜  ♞  ♝  ♚  ♛  ♝  ♞  ♜ │
      └────────────────────────┘
        h  g  f  e  d  c  b  a

  Black | h:hint r:reveal n:next Esc:back q:quit
"
}

pub fn puzzle_incorrect_then_hint_snapshot_test() {
  let state = puzzle_snapshot_state()
  // Type incorrect move "e5" and submit
  let #(state, _) = app.update(state, event.Char("e"))
  let #(state, _) = app.update(state, event.Char("5"))
  let #(state, _) = app.update(state, event.Enter)
  // Request hint after incorrect guess
  let #(state, _) = app.update(state, event.Char("h"))
  let result = render_puzzle_snapshot(state)
  assert result
    == "
      ┌────────────────────────┐  Puzzle 1/1  Mistake
    1 │ ♜  ♞  ♝  ♚  ♛  ♝  ♞  ♜ │  Find the best move for Black
    2 │ ♟  ♟  ♟     ♟  ♟  ♟  ♟ │
    3 │                        │
    4 │          ♟             │  Move your pawn
    5 │                        │
    6 │                        │
    7 │ ♟  ♟  ♟  ♟  ♟  ♟  ♟  ♟ │
    8 │ ♜  ♞  ♝  ♚  ♛  ♝  ♞  ♜ │
      └────────────────────────┘
        h  g  f  e  d  c  b  a

  Black | h:hint r:reveal n:next Esc:back q:quit
"
}

pub fn puzzle_revealed_snapshot_test() {
  let state = puzzle_snapshot_state()
  let #(state, _) = app.update(state, event.Char("r"))
  let result = render_puzzle_snapshot(state)
  assert result
    == "
      ┌────────────────────────┐  Puzzle 1/1  Mistake
    1 │ ♜  ♞  ♝  ♚  ♛  ♝  ♞  ♜ │  Find the best move for Black
    2 │ ♟  ♟  ♟     ♟  ♟  ♟  ♟ │
    3 │                        │  Best: d5 (eval +0.2)
    4 │          ♟             │  You played: e5 (eval +1.7)
    5 │                        │  1...d5 2. exd5 Qxd5
    6 │                        │
    7 │ ♟  ♟  ♟  ♟  ♟  ♟  ♟  ♟ │
    8 │ ♜  ♞  ♝  ♚  ♛  ♝  ♞  ♜ │
      └────────────────────────┘
        h  g  f  e  d  c  b  a

  Black | h:hint r:reveal n:next Esc:back q:quit
"
}

pub fn puzzle_correct_snapshot_test() {
  let state = puzzle_snapshot_state()
  let #(state, _) = app.update(state, event.Char("d"))
  let #(state, _) = app.update(state, event.Char("5"))
  let #(state, _) = app.update(state, event.Enter)
  let result = render_puzzle_snapshot(state)
  assert result
    == "
      ┌────────────────────────┐  Puzzle 1/1  Mistake
    1 │ ♜  ♞  ♝  ♚  ♛  ♝  ♞  ♜ │  Find the best move for Black
    2 │ ♟  ♟  ♟     ♟  ♟  ♟  ♟ │
    3 │                        │  Correct!
    4 │          ♟             │
    5 │                        │
    6 │                        │
    7 │ ♟  ♟  ♟  ♟  ♟  ♟  ♟  ♟ │
    8 │ ♜  ♞  ♝  ♚  ♛  ♝  ♞  ♜ │
      └────────────────────────┘
        h  g  f  e  d  c  b  a

  Black | h:hint r:reveal n:next Esc:back q:quit
"
}

// --- Helpers ---

fn render_snapshot(state: app.AppState) -> String {
  let commands = render_full_ui(state)
  virtual_terminal.render_to_string(commands, 50, 15)
}

fn render_puzzle_snapshot(state: app.AppState) -> String {
  let commands = render_full_ui(state)
  virtual_terminal.render_to_string(commands, 70, 15)
}

fn render_full_ui(state: AppState) -> List(command.Command) {
  case state.mode {
    GameBrowser -> {
      let browser_commands = game_browser_view.render(state)
      let status_commands = status_bar.render(state, 13)
      list.flatten([browser_commands, status_commands])
    }
    PuzzleTraining -> {
      let assert Some(session) = state.puzzle_session
      let assert Some(p) = puzzle.current_puzzle(session)
      let pos = case fen.parse(p.fen) {
        Ok(position) -> position
        Error(_) -> game.current_position(state.game)
      }
      let #(best_from, best_to) = case state.puzzle_phase {
        puzzle.Revealed | puzzle.Correct -> parse_uci_squares(p.solution_uci)
        _ -> #(None, None)
      }
      let options =
        RenderOptions(
          from_white: state.from_white,
          last_move_from: None,
          last_move_to: None,
          check_square: None,
          best_move_from: best_from,
          best_move_to: best_to,
        )
      let board_commands = board_view.render(pos.board, options)
      let panel_commands =
        puzzle_view.render(
          session,
          state.puzzle_phase,
          state.puzzle_feedback,
          pos.board,
          state.input_buffer,
          34, 1, 10,
        )
      let status_commands = status_bar.render(state, 13)
      list.flatten([board_commands, panel_commands, status_commands])
    }
    _ -> {
      let pos = game.current_position(state.game)
      let last = app.last_move(state)
      let check_square = case move_gen.is_in_check(pos, pos.active_color) {
        True -> move_gen.find_king(pos.board, pos.active_color)
        False -> None
      }
      let #(best_from, best_to) = best_move_squares(state)
      let options =
        RenderOptions(
          from_white: state.from_white,
          last_move_from: option.map(last, fn(m) { m.from }),
          last_move_to: option.map(last, fn(m) { m.to }),
          check_square: check_square,
          best_move_from: best_from,
          best_move_to: best_to,
        )

      let board_commands = board_view.render(pos.board, options)
      let white_name = option.from_result(dict.get(state.game.tags, "White"))
      let black_name = option.from_result(dict.get(state.game.tags, "Black"))
      let captures_commands =
        captures_view.render(pos.board, state.from_white, 0, 12, 7, white_name, black_name)
      let panel_commands = info_panel.render(state.game, 34, 1, 10, state.analysis, state.deep_analysis_index)
      let eval_commands = render_eval_bar(state)
      let status_commands = status_bar.render(state, 13)
      list.flatten([
        board_commands,
        captures_commands,
        panel_commands,
        eval_commands,
        status_commands,
      ])
    }
  }
}

fn best_move_squares(state: AppState) -> #(option.Option(square.Square), option.Option(square.Square)) {
  case state.analysis {
    Some(ga) -> {
      let idx = state.game.current_index
      case list.drop(ga.move_analyses, idx) |> list.first {
        Ok(ma) -> parse_uci_squares(ma.best_move_uci)
        Error(_) -> #(None, None)
      }
    }
    None -> #(None, None)
  }
}

fn parse_uci_squares(uci_str: String) -> #(option.Option(square.Square), option.Option(square.Square)) {
  let from_str = string.slice(uci_str, 0, 2)
  let to_str = string.slice(uci_str, 2, 2)
  let from = option.from_result(square.from_string(from_str))
  let to = option.from_result(square.from_string(to_str))
  #(from, to)
}

fn render_eval_bar(state: AppState) -> List(command.Command) {
  case state.analysis {
    Some(ga) -> {
      let idx = state.game.current_index
      case list.drop(ga.evaluations, idx) |> list.first {
        Ok(score) -> eval_bar.render(score, 0, 2, 8)
        Error(_) -> []
      }
    }
    None -> []
  }
}

