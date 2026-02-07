//// Mode-aware status bar displayed below the board.
//// Shows current mode, side to move, available keybindings, and error messages.

import chesscli/chess/color
import chesscli/chess/game
import chesscli/engine/uci
import chesscli/tui/app.{
  type AppState, ArchiveList, FreePlay, GameBrowser, GameList, GameReplay,
  LoadError, LoadingArchives, LoadingGames, MoveInput, UsernameInput,
}
import etch/command
import etch/terminal
import gleam/int
import gleam/list
import gleam/option

/// Format the status text based on the current app state.
pub fn format_status(state: AppState) -> String {
  case state.analysis_progress {
    option.Some(#(done, total)) ->
      "[ANALYZING] "
      <> int.to_string(done)
      <> "/"
      <> int.to_string(total)
      <> " positions..."
    option.None -> format_mode_status(state)
  }
}

fn format_mode_status(state: AppState) -> String {
  let pos = game.current_position(state.game)
  let side = color.to_string(pos.active_color)
  case state.mode {
    GameReplay -> format_replay_status(state, side)
    FreePlay ->
      "[PLAY] " <> side <> " | u:undo f:flip q:quit"
    MoveInput -> "> " <> state.input_buffer <> "\u{2588}"
    GameBrowser -> format_browser_status(state)
  }
}

fn format_replay_status(state: AppState, side: String) -> String {
  case state.analysis {
    option.Some(ga) -> {
      let eval_str = case current_eval(ga, state.game.current_index) {
        option.Some(score) -> " | " <> uci.format_score(score)
        option.None -> ""
      }
      "[REPLAY] "
      <> side
      <> eval_str
      <> " | \u{2190}\u{2192} Home End f q"
    }
    option.None ->
      "[REPLAY] "
      <> side
      <> " | \u{2190}\u{2192} Home End f r q"
  }
}

import chesscli/engine/analysis.{type GameAnalysis}

fn current_eval(ga: GameAnalysis, index: Int) -> option.Option(uci.Score) {
  ga.evaluations
  |> list.drop(index)
  |> list.first
  |> option.from_result
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

fn format_browser_status(state: AppState) -> String {
  case state.browser {
    option.Some(browser) ->
      case browser.phase {
        UsernameInput -> "[BROWSE] Enter username | Esc:back"
        LoadingArchives | LoadingGames -> "[BROWSE] Loading..."
        ArchiveList -> "[BROWSE] \u{2191}\u{2193}:select Enter:open Esc:back q:quit"
        GameList -> "[BROWSE] \u{2191}\u{2193}:select Enter:load Esc:back q:quit"
        LoadError -> "[BROWSE] Error | Esc:back q:quit"
      }
    option.None -> "[BROWSE]"
  }
}
