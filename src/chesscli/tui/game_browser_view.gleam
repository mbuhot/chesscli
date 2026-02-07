//// Renders the chess.com game browser UI, replacing the board view
//// when in GameBrowser mode.

import chesscli/chesscom/api
import chesscli/tui/app.{
  type AppState, type BrowserState, ArchiveList, GameList, LoadError,
  LoadingArchives, LoadingGames, UsernameInput,
}
import etch/command
import gleam/int
import gleam/list
import gleam/option

/// Render the browser view as a list of etch commands.
pub fn render(state: AppState) -> List(command.Command) {
  case state.browser {
    option.Some(browser) -> render_browser(browser)
    option.None -> []
  }
}

fn render_browser(browser: BrowserState) -> List(command.Command) {
  case browser.phase {
    UsernameInput -> render_username_input(browser)
    LoadingArchives | LoadingGames -> render_loading()
    ArchiveList -> render_archive_list(browser)
    GameList -> render_game_list(browser)
    LoadError -> render_error(browser)
  }
}

fn render_username_input(browser: BrowserState) -> List(command.Command) {
  let prompt = "Chess.com username: " <> browser.input_buffer <> "\u{2588}"
  [command.MoveTo(2, 1), command.Print(prompt)]
}

fn render_loading() -> List(command.Command) {
  [command.MoveTo(2, 1), command.Print("Loading...")]
}

fn render_archive_list(browser: BrowserState) -> List(command.Command) {
  let title = "Archives for " <> browser.username
  let title_commands = [command.MoveTo(2, 1), command.Print(title)]
  let items =
    browser.archives
    |> visible_window(browser.archive_cursor, 10)
    |> list.index_map(fn(item, i) {
      let #(label, index) = item
      let prefix = case index == browser.archive_cursor {
        True -> "> "
        False -> "  "
      }
      [
        command.MoveTo(2, 3 + i),
        command.Print(prefix <> api.format_archive_label(label)),
      ]
    })
    |> list.flatten
  list.flatten([title_commands, items])
}

fn render_game_list(browser: BrowserState) -> List(command.Command) {
  let title =
    "Games for "
    <> browser.username
    <> " ("
    <> int.to_string(list.length(browser.games))
    <> ")"
  let title_commands = [command.MoveTo(2, 1), command.Print(title)]
  let items =
    browser.games
    |> list.index_map(fn(game, i) { #(game, i) })
    |> visible_window_pairs(browser.game_cursor, 10)
    |> list.index_map(fn(item, i) {
      let #(game, index) = item
      let prefix = case index == browser.game_cursor {
        True -> "> "
        False -> "  "
      }
      [
        command.MoveTo(2, 3 + i),
        command.Print(prefix <> api.format_game_line(game, browser.username)),
      ]
    })
    |> list.flatten
  list.flatten([title_commands, items])
}

fn render_error(browser: BrowserState) -> List(command.Command) {
  [command.MoveTo(2, 1), command.Print("Error: " <> browser.error)]
}

/// Create a visible window of items around the cursor position.
/// Returns list of #(item, original_index) pairs.
fn visible_window(
  items: List(String),
  cursor: Int,
  max_visible: Int,
) -> List(#(String, Int)) {
  items
  |> list.index_map(fn(item, i) { #(item, i) })
  |> window_slice(cursor, max_visible)
}

fn visible_window_pairs(
  items: List(#(a, Int)),
  cursor: Int,
  max_visible: Int,
) -> List(#(a, Int)) {
  items
  |> window_slice(cursor, max_visible)
}

fn window_slice(items: List(a), cursor: Int, max_visible: Int) -> List(a) {
  let total = list.length(items)
  case total <= max_visible {
    True -> items
    False -> {
      let half = max_visible / 2
      let start = int.max(0, int.min(cursor - half, total - max_visible))
      items
      |> list.drop(start)
      |> list.take(max_visible)
    }
  }
}
