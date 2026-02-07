//// Mode-aware status bar displayed below the board.
//// Shows current mode, side to move, available keybindings, and error messages.

import chesscli/chess/color
import chesscli/chess/game
import chesscli/tui/app.{type AppState, FreePlay, GameReplay, MoveInput}
import etch/command
import etch/terminal

/// Format the status text based on the current app state.
pub fn format_status(state: AppState) -> String {
  let pos = game.current_position(state.game)
  let side = color.to_string(pos.active_color)
  case state.mode {
    GameReplay ->
      "[REPLAY] " <> side <> " | \u{2190}\u{2192} Home End f q"
    FreePlay ->
      "[PLAY] " <> side <> " | u:undo f:flip q:quit"
    MoveInput -> "> " <> state.input_buffer <> "\u{2588}"
  }
}

/// Format the error message, if any.
pub fn format_error(state: AppState) -> String {
  state.input_error
}

/// Render the status bar at the given row as positioned terminal commands.
pub fn render(state: AppState, row: Int) -> List(command.Command) {
  let status = format_status(state)
  let error = format_error(state)
  let clear_eol = command.Clear(terminal.UntilNewLine)
  let error_commands = [
    command.MoveTo(2, row + 1),
    command.ResetStyle,
    command.Print(error),
    clear_eol,
  ]
  [command.MoveTo(2, row), command.ResetStyle, command.Print(status), clear_eol, ..error_commands]
}
