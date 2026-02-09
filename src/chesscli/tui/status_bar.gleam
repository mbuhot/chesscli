//// Mode-aware status bar displayed below the board.
//// Shows input buffer, analysis progress, and browser prompts.

import chesscli/tui/app.{
  type AppState, ArchiveList, FreePlay, GameBrowser, GameList, GameReplay,
  LoadError, LoadingArchives, LoadingGames, PuzzleExplore, PuzzleTraining,
  UsernameInput,
}
import etch/command
import etch/terminal
import gleam/int
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
  case state.input_buffer {
    "" -> format_mode_label(state)
    buffer -> "> " <> buffer <> "\u{2588}"
  }
}

fn format_mode_label(state: AppState) -> String {
  case state.mode {
    GameReplay | FreePlay | PuzzleTraining | PuzzleExplore -> ""
    GameBrowser -> format_browser_status(state)
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
