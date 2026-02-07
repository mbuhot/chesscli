import chesscli/chess/game
import chesscli/chess/pgn
import chesscli/chess/square
import chesscli/tui/app.{AppState, FreePlay, GameReplay, MoveInput, None, Quit, Render}
import etch/event
import gleam/list
import gleam/option

// --- Helper ---

fn sample_game() -> game.Game {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3 Nc6")
  game.from_pgn(pgn_game)
}

// --- Constructor tests ---

pub fn new_creates_free_play_test() {
  let state = app.new()
  assert state.mode == FreePlay
  assert state.from_white == True
  assert state.input_buffer == ""
  assert state.input_error == ""
  assert state.game.current_index == 0
}

pub fn from_game_creates_game_replay_test() {
  let state = app.from_game(sample_game())
  assert state.mode == GameReplay
  assert state.from_white == True
  assert state.game.current_index == 0
  assert list.length(state.game.moves) == 4
}

// --- GameReplay: navigation ---

pub fn replay_right_arrow_advances_test() {
  let state = app.from_game(sample_game())
  let #(state, effect) = app.update(state, event.RightArrow)
  assert state.game.current_index == 1
  assert effect == Render
}

pub fn replay_right_arrow_at_end_is_none_test() {
  let state = app.from_game(sample_game())
  let state = AppState(..state, game: game.goto_end(state.game))
  let #(state, effect) = app.update(state, event.RightArrow)
  assert state.game.current_index == 4
  assert effect == None
}

pub fn replay_left_arrow_goes_back_test() {
  let state = app.from_game(sample_game())
  let #(state, _) = app.update(state, event.RightArrow)
  let #(state, _) = app.update(state, event.RightArrow)
  let #(state, effect) = app.update(state, event.LeftArrow)
  assert state.game.current_index == 1
  assert effect == Render
}

pub fn replay_left_arrow_at_start_is_none_test() {
  let state = app.from_game(sample_game())
  let #(state, effect) = app.update(state, event.LeftArrow)
  assert state.game.current_index == 0
  assert effect == None
}

pub fn replay_home_jumps_to_start_test() {
  let state = app.from_game(sample_game())
  let state = AppState(..state, game: game.goto_end(state.game))
  let #(state, effect) = app.update(state, event.Home)
  assert state.game.current_index == 0
  assert effect == Render
}

pub fn replay_end_jumps_to_end_test() {
  let state = app.from_game(sample_game())
  let #(state, effect) = app.update(state, event.End)
  assert state.game.current_index == 4
  assert effect == Render
}

// --- GameReplay: flip, quit, move input ---

pub fn replay_f_flips_board_test() {
  let state = app.from_game(sample_game())
  assert state.from_white == True
  let #(state, effect) = app.update(state, event.Char("f"))
  assert state.from_white == False
  assert effect == Render
}

pub fn replay_q_quits_test() {
  let state = app.from_game(sample_game())
  let #(_, effect) = app.update(state, event.Char("q"))
  assert effect == Quit
}

pub fn replay_typing_auto_enters_move_input_test() {
  let state = app.from_game(sample_game())
  let #(state, effect) = app.update(state, event.Char("e"))
  assert state.mode == MoveInput
  assert state.input_buffer == "e"
  assert effect == Render
}

pub fn replay_unknown_key_is_none_test() {
  let state = app.from_game(sample_game())
  let #(_, effect) = app.update(state, event.Char("x"))
  assert effect == None
}

pub fn replay_piece_char_auto_enters_move_input_test() {
  let state = app.from_game(sample_game())
  let #(state, effect) = app.update(state, event.Char("N"))
  assert state.mode == MoveInput
  assert state.input_buffer == "N"
  assert effect == Render
}

// --- MoveInput: buffer manipulation ---

pub fn input_char_appends_to_buffer_test() {
  let state = AppState(..app.new(), mode: MoveInput)
  let #(state, effect) = app.update(state, event.Char("e"))
  assert state.input_buffer == "e"
  assert effect == Render
  let #(state, _) = app.update(state, event.Char("4"))
  assert state.input_buffer == "e4"
}

pub fn input_backspace_removes_last_char_test() {
  let state = AppState(..app.new(), mode: MoveInput, input_buffer: "e4")
  let #(state, effect) = app.update(state, event.Backspace)
  assert state.input_buffer == "e"
  assert effect == Render
}

pub fn input_backspace_on_empty_buffer_test() {
  let state = AppState(..app.new(), mode: MoveInput, input_buffer: "")
  let #(state, effect) = app.update(state, event.Backspace)
  assert state.input_buffer == ""
  assert effect == Render
}

pub fn input_char_clears_error_test() {
  let state =
    AppState(..app.new(), mode: MoveInput, input_error: "Invalid: xyz")
  let #(state, _) = app.update(state, event.Char("e"))
  assert state.input_error == ""
}

// --- MoveInput: escape ---

pub fn input_escape_returns_to_free_play_test() {
  let state = AppState(..app.new(), mode: MoveInput, input_buffer: "e4")
  let #(state, effect) = app.update(state, event.Esc)
  assert state.mode == FreePlay
  assert state.input_buffer == ""
  assert effect == Render
}

pub fn input_escape_from_replay_returns_to_replay_test() {
  let state = app.from_game(sample_game())
  // Enter move input from GameReplay by typing a SAN char
  let #(state, _) = app.update(state, event.Char("e"))
  assert state.mode == MoveInput
  let #(state, _) = app.update(state, event.Esc)
  assert state.mode == GameReplay
}

// --- MoveInput: enter with valid move ---

pub fn input_enter_valid_move_applies_test() {
  let state = AppState(..app.new(), mode: MoveInput, input_buffer: "e4")
  let #(state, effect) = app.update(state, event.Enter)
  assert state.mode == FreePlay
  assert state.game.current_index == 1
  assert state.input_buffer == ""
  assert state.input_error == ""
  assert effect == Render
}

pub fn input_enter_invalid_move_shows_error_test() {
  let state = AppState(..app.new(), mode: MoveInput, input_buffer: "xyz")
  let #(state, effect) = app.update(state, event.Enter)
  assert state.mode == MoveInput
  assert state.input_error == "Invalid: xyz"
  assert effect == Render
}

pub fn input_enter_from_replay_mid_game_test() {
  // From GameReplay at move 2 (after e4 e5), type Nf3 — should become FreePlay
  let state = app.from_game(sample_game())
  let #(state, _) = app.update(state, event.RightArrow)
  let #(state, _) = app.update(state, event.RightArrow)
  // Now at index 2 (after 1. e4 e5), typing "N" auto-enters MoveInput
  let #(state, _) = app.update(state, event.Char("N"))
  assert state.mode == MoveInput
  assert state.input_buffer == "N"
  let #(state, _) = app.update(state, event.Char("f"))
  let #(state, _) = app.update(state, event.Char("3"))
  let #(state, effect) = app.update(state, event.Enter)
  assert state.mode == FreePlay
  assert state.game.current_index == 3
  assert effect == Render
}

// --- FreePlay: undo, flip, quit ---

pub fn free_play_undo_goes_back_test() {
  let state = app.new()
  // Make a move first via MoveInput
  let state = AppState(..state, mode: MoveInput, input_buffer: "e4")
  let #(state, _) = app.update(state, event.Enter)
  assert state.game.current_index == 1
  // Now undo
  let #(state, effect) = app.update(state, event.Char("u"))
  assert state.game.current_index == 0
  assert effect == Render
}

pub fn free_play_undo_at_start_is_none_test() {
  let state = app.new()
  let #(_, effect) = app.update(state, event.Char("u"))
  assert effect == None
}

pub fn free_play_f_flips_board_test() {
  let state = app.new()
  let #(state, effect) = app.update(state, event.Char("f"))
  assert state.from_white == False
  assert effect == Render
}

pub fn free_play_q_quits_test() {
  let state = app.new()
  let #(_, effect) = app.update(state, event.Char("q"))
  assert effect == Quit
}

pub fn free_play_typing_auto_enters_move_input_test() {
  let state = app.new()
  let #(state, effect) = app.update(state, event.Char("d"))
  assert state.mode == MoveInput
  assert state.input_buffer == "d"
  assert effect == Render
}

pub fn free_play_full_move_input_flow_test() {
  // Type d4 directly in FreePlay — should auto-enter MoveInput and apply
  let state = app.new()
  let #(state, _) = app.update(state, event.Char("d"))
  assert state.mode == MoveInput
  let #(state, _) = app.update(state, event.Char("4"))
  assert state.input_buffer == "d4"
  let #(state, effect) = app.update(state, event.Enter)
  assert state.mode == FreePlay
  assert state.game.current_index == 1
  assert effect == Render
}

// --- MoveInput: raw key codes from JS target ---
// Etch on JS sends Enter as Char("\r"), Esc as Char("\u{001b}"),
// and Backspace as Char("\u{007f}") instead of the named KeyCode variants.

pub fn input_carriage_return_submits_move_test() {
  let state = AppState(..app.new(), mode: MoveInput, input_buffer: "e4")
  let #(state, effect) = app.update(state, event.Char("\r"))
  assert state.mode == FreePlay
  assert state.game.current_index == 1
  assert effect == Render
}

pub fn input_escape_char_cancels_input_test() {
  let state = AppState(..app.new(), mode: MoveInput, input_buffer: "e4")
  let #(state, effect) = app.update(state, event.Char("\u{001b}"))
  assert state.mode == FreePlay
  assert state.input_buffer == ""
  assert effect == Render
}

pub fn input_delete_char_removes_last_char_test() {
  let state = AppState(..app.new(), mode: MoveInput, input_buffer: "e4")
  let #(state, effect) = app.update(state, event.Char("\u{007f}"))
  assert state.input_buffer == "e"
  assert effect == Render
}

// --- last_move ---

pub fn last_move_at_start_is_none_test() {
  let state = app.from_game(sample_game())
  assert app.last_move(state) == option.None
}

pub fn last_move_after_first_move_test() {
  let state = app.from_game(sample_game())
  let #(state, _) = app.update(state, event.RightArrow)
  let assert option.Some(m) = app.last_move(state)
  // First move is e2-e4
  assert m.from == square.e2
  assert m.to == square.e4
}

pub fn last_move_after_second_move_test() {
  let state = app.from_game(sample_game())
  let #(state, _) = app.update(state, event.RightArrow)
  let #(state, _) = app.update(state, event.RightArrow)
  let assert option.Some(m) = app.last_move(state)
  // Second move is e7-e5
  assert m.from == square.e7
  assert m.to == square.e5
}

pub fn last_move_in_free_play_after_move_test() {
  let state = app.new()
  let state = AppState(..state, mode: MoveInput, input_buffer: "e4")
  let #(state, _) = app.update(state, event.Enter)
  let assert option.Some(m) = app.last_move(state)
  assert m.from == square.e2
  assert m.to == square.e4
}
