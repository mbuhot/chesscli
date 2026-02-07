import chesscli/chess/game
import chesscli/chess/move_gen
import chesscli/chess/pgn
import chesscli/tui/app.{AppState}
import chesscli/tui/board_view.{RenderOptions}
import chesscli/tui/captures_view
import chesscli/tui/info_panel
import chesscli/tui/status_bar
import chesscli/tui/virtual_terminal
import etch/command
import etch/event
import etch/style
import gleam/list
import gleam/option.{None}

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

  [REPLAY] White | ←→ Home End f q
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

// --- Helpers ---

fn render_snapshot(state: app.AppState) -> String {
  let commands = render_full_ui(state)
  virtual_terminal.render_to_string(commands, 50, 15)
}

fn render_full_ui(state: app.AppState) -> List(command.Command) {
  let pos = game.current_position(state.game)
  let last = app.last_move(state)
  let check_square = case move_gen.is_in_check(pos, pos.active_color) {
    True -> move_gen.find_king(pos.board, pos.active_color)
    False -> None
  }
  let options =
    RenderOptions(
      from_white: state.from_white,
      last_move_from: option.map(last, fn(m) { m.from }),
      last_move_to: option.map(last, fn(m) { m.to }),
      check_square: check_square,
    )

  let board_commands = board_view.render(pos.board, options)
  let captures_commands =
    captures_view.render(pos.board, state.from_white, 0, 12, 4)
  let panel_commands = info_panel.render(state.game, 31, 1)
  let status_commands = status_bar.render(state, 13)
  list.flatten([
    board_commands,
    captures_commands,
    panel_commands,
    status_commands,
  ])
}
