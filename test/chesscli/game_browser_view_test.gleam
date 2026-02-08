import chesscli/chesscom/api
import chesscli/tui/app.{
  type AppState, AppState, BrowserState, GameBrowser, GameList, LoadError,
}
import chesscli/tui/game_browser_view
import chesscli/tui/virtual_terminal
import etch/event
import gleam/option
import gleam/string

fn render_to_text(state: AppState) -> String {
  let commands = game_browser_view.render(state)
  virtual_terminal.render_to_string(commands, 60, 15)
}

fn browser_state_with_phase(phase: app.BrowserPhase) -> AppState {
  let browser =
    BrowserState(
      username: "hikaru",
      input_buffer: "",
      archives: [],
      archive_cursor: 0,
      games: [],
      game_cursor: 0,
      phase: phase,
      error: "",
    )
  AppState(..app.new(), mode: GameBrowser, browser: option.Some(browser))
}

pub fn username_input_prompt_test() {
  let state = app.new()
  // Open menu, press 'b' to browse
  let #(state, _) = app.update(state, event.Esc)
  let #(state, _) = app.update(state, event.Char("b"))
  let #(state, _) = app.update(state, event.Char("h"))
  let #(state, _) = app.update(state, event.Char("i"))
  let result = render_to_text(state)
  assert string.contains(result, "Chess.com username: hi█") == True
}

pub fn loading_screen_test() {
  let state = browser_state_with_phase(app.LoadingArchives)
  let result = render_to_text(state)
  assert string.contains(result, "Loading...") == True
}

pub fn archive_list_with_cursor_test() {
  let browser =
    BrowserState(
      username: "hikaru",
      input_buffer: "",
      archives: [
        "https://api.chess.com/pub/player/hikaru/games/2024/02",
        "https://api.chess.com/pub/player/hikaru/games/2024/01",
      ],
      archive_cursor: 0,
      games: [],
      game_cursor: 0,
      phase: app.ArchiveList,
      error: "",
    )
  let state =
    AppState(..app.new(), mode: GameBrowser, browser: option.Some(browser))
  let result = render_to_text(state)
  assert string.contains(result, "> 2024/02") == True
  assert string.contains(result, "  2024/01") == True
}

pub fn archive_list_cursor_moves_test() {
  let browser =
    BrowserState(
      username: "hikaru",
      input_buffer: "",
      archives: [
        "https://api.chess.com/pub/player/hikaru/games/2024/02",
        "https://api.chess.com/pub/player/hikaru/games/2024/01",
      ],
      archive_cursor: 1,
      games: [],
      game_cursor: 0,
      phase: app.ArchiveList,
      error: "",
    )
  let state =
    AppState(..app.new(), mode: GameBrowser, browser: option.Some(browser))
  let result = render_to_text(state)
  assert string.contains(result, "  2024/02") == True
  assert string.contains(result, "> 2024/01") == True
}

pub fn error_screen_test() {
  let browser =
    BrowserState(
      username: "hikaru",
      input_buffer: "",
      archives: [],
      archive_cursor: 0,
      games: [],
      game_cursor: 0,
      phase: LoadError,
      error: "network failure",
    )
  let state =
    AppState(..app.new(), mode: GameBrowser, browser: option.Some(browser))
  let result = render_to_text(state)
  assert string.contains(result, "Error: network failure") == True
}

pub fn game_list_with_cursor_test() {
  let game1 =
    api.GameSummary(
      url: "",
      pgn: "1. e4 e5",
      time_control: "180",
      time_class: "blitz",
      end_time: 0,
      rated: True,
      white: api.PlayerInfo("hikaru", 2900, "win"),
      black: api.PlayerInfo("opponent", 2700, "checkmated"),
      accuracy_white: 0.0,
      accuracy_black: 0.0,
    )
  let game2 =
    api.GameSummary(
      ..game1,
      white: api.PlayerInfo("other", 2600, "win"),
      black: api.PlayerInfo("hikaru", 2900, "resigned"),
    )
  let browser =
    BrowserState(
      username: "hikaru",
      input_buffer: "",
      archives: [],
      archive_cursor: 0,
      games: [game1, game2],
      game_cursor: 0,
      phase: GameList,
      error: "",
    )
  let state =
    AppState(..app.new(), mode: GameBrowser, browser: option.Some(browser))
  let result = render_to_text(state)
  assert string.contains(result, "> W vs opponent(2700) blitz") == True
  assert string.contains(result, "  L vs other(2600) blitz") == True
}
