//// Elm-style state machine for the TUI application.
//// All input handling is a pure update(state, key) -> #(state, effect)
//// function, keeping side effects at the boundary in chesscli.gleam.

import chesscli/chess/game.{type Game}
import chesscli/chess/move.{type Move}
import etch/event.{type KeyCode}
import gleam/option.{type Option}

/// The current interaction mode of the application.
pub type Mode {
  /// Navigating through a loaded game's move history.
  GameReplay
  /// Playing moves freely from the current position.
  FreePlay
  /// Typing a SAN move string to apply.
  MoveInput
}

/// The complete application state, designed for pure update functions.
pub type AppState {
  AppState(
    game: Game,
    mode: Mode,
    from_white: Bool,
    input_buffer: String,
    input_error: String,
  )
}

/// Side effects that the event loop should perform after an update.
pub type Effect {
  Render
  Quit
  None
}

/// Create a new app state in FreePlay mode with a fresh game.
pub fn new() -> AppState {
  AppState(
    game: game.new(),
    mode: FreePlay,
    from_white: True,
    input_buffer: "",
    input_error: "",
  )
}

/// Create an app state in GameReplay mode from a loaded game.
pub fn from_game(g: Game) -> AppState {
  AppState(
    game: g,
    mode: GameReplay,
    from_white: True,
    input_buffer: "",
    input_error: "",
  )
}

/// Pure state transition: given current state and a key press, return
/// the new state and any side effect to perform.
pub fn update(state: AppState, key: KeyCode) -> #(AppState, Effect) {
  case state.mode {
    GameReplay -> update_game_replay(state, key)
    FreePlay -> update_free_play(state, key)
    MoveInput -> update_move_input(state, key)
  }
}

/// Derive the last move played from the game cursor position.
pub fn last_move(state: AppState) -> Option(Move) {
  case state.game.current_index > 0 {
    True -> list_at(state.game.moves, state.game.current_index - 1)
    False -> option.None
  }
}

fn update_game_replay(state: AppState, key: KeyCode) -> #(AppState, Effect) {
  case key {
    event.RightArrow ->
      case game.forward(state.game) {
        Ok(g) -> #(AppState(..state, game: g), Render)
        Error(_) -> #(state, None)
      }
    event.LeftArrow ->
      case game.backward(state.game) {
        Ok(g) -> #(AppState(..state, game: g), Render)
        Error(_) -> #(state, None)
      }
    event.Home -> #(AppState(..state, game: game.goto_start(state.game)), Render)
    event.End -> #(AppState(..state, game: game.goto_end(state.game)), Render)
    event.Char("f") -> #(AppState(..state, from_white: !state.from_white), Render)
    event.Char("q") -> #(state, Quit)
    event.Char("/") -> enter_move_input(state)
    event.Char(c) -> try_auto_input(state, c)
    _ -> #(state, None)
  }
}

fn update_free_play(state: AppState, key: KeyCode) -> #(AppState, Effect) {
  case key {
    event.Char("u") ->
      case game.backward(state.game) {
        Ok(g) -> #(AppState(..state, game: g), Render)
        Error(_) -> #(state, None)
      }
    event.Char("f") -> #(AppState(..state, from_white: !state.from_white), Render)
    event.Char("q") -> #(state, Quit)
    event.Char("/") -> enter_move_input(state)
    event.Char(c) -> try_auto_input(state, c)
    _ -> #(state, None)
  }
}

fn enter_move_input(state: AppState) -> #(AppState, Effect) {
  #(
    AppState(..state, mode: MoveInput, input_buffer: "", input_error: ""),
    Render,
  )
}

fn update_move_input(state: AppState, key: KeyCode) -> #(AppState, Effect) {
  case key {
    event.Esc | event.Char("\u{001b}") -> #(
      AppState(
        ..state,
        mode: prev_mode_from_game(state),
        input_buffer: "",
        input_error: "",
      ),
      Render,
    )
    event.Enter | event.Char("\r") -> apply_input_move(state)
    event.Backspace | event.Char("\u{007f}") -> {
      let new_buffer = string.drop_end(state.input_buffer, 1)
      #(AppState(..state, input_buffer: new_buffer, input_error: ""), Render)
    }
    event.Char(c) -> #(
      AppState(..state, input_buffer: state.input_buffer <> c, input_error: ""),
      Render,
    )
    _ -> #(state, None)
  }
}

import chesscli/chess/san
import gleam/list
import gleam/string

/// Auto-enter MoveInput when a SAN-starting character is typed.
fn try_auto_input(state: AppState, c: String) -> #(AppState, Effect) {
  case is_san_char(c) {
    True -> #(
      AppState(..state, mode: MoveInput, input_buffer: c, input_error: ""),
      Render,
    )
    False -> #(state, None)
  }
}

/// Characters that can start or continue a SAN move string.
fn is_san_char(c: String) -> Bool {
  case c {
    // Files
    "a" | "b" | "c" | "d" | "e" | "g" | "h" -> True
    // Ranks
    "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" -> True
    // Pieces
    "N" | "B" | "R" | "Q" | "K" -> True
    // Castling
    "O" -> True
    _ -> False
  }
}

fn apply_input_move(state: AppState) -> #(AppState, Effect) {
  let pos = game.current_position(state.game)
  case san.parse(state.input_buffer, pos) {
    Ok(m) ->
      case game.apply_move(state.game, m) {
        Ok(g) -> #(
          AppState(..state, game: g, mode: FreePlay, input_buffer: "", input_error: ""),
          Render,
        )
        Error(_) -> #(
          AppState(..state, input_error: "Illegal move"),
          Render,
        )
      }
    Error(_) -> #(
      AppState(..state, input_error: "Invalid: " <> state.input_buffer),
      Render,
    )
  }
}

/// Determine which mode to return to when cancelling MoveInput.
fn prev_mode_from_game(state: AppState) -> Mode {
  // If there are moves after the cursor, we were in GameReplay
  case state.game.current_index < list.length(state.game.moves) {
    True -> GameReplay
    False -> FreePlay
  }
}

fn list_at(lst: List(a), index: Int) -> Option(a) {
  case lst, index {
    [], _ -> option.None
    [head, ..], 0 -> option.Some(head)
    [_, ..tail], n if n > 0 -> list_at(tail, n - 1)
    _, _ -> option.None
  }
}
