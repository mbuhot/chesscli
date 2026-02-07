import chesscli/chess/game
import chesscli/chess/pgn
import chesscli/chess/square
import chesscli/chesscom/api
import chesscli/engine/analysis.{Blunder, GameAnalysis, MoveAnalysis}
import chesscli/engine/uci.{Centipawns}
import chesscli/tui/app.{
  type AppState, AnalyzeGame, AppState, ArchiveList, FetchArchives, FetchGames,
  FreePlay, GameBrowser, GameList, GameReplay, LoadError, LoadingArchives,
  LoadingGames, MoveInput, None, Quit, Render, UsernameInput,
}
import etch/event
import gleam/list
import gleam/option

// --- Helper ---

fn sample_game() -> game.Game {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3 Nc6")
  game.from_pgn(pgn_game)
}

fn long_game() -> game.Game {
  let assert Ok(pgn_game) =
    pgn.parse(
      "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7",
    )
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

pub fn replay_page_down_skips_forward_10_turns_test() {
  let state = app.from_game(long_game())
  let #(state, effect) = app.update(state, event.PageDown)
  // 10 full turns = 20 plies, long_game has exactly 20 plies
  assert state.game.current_index == 20
  assert effect == Render
}

pub fn replay_page_down_clamps_to_end_test() {
  let state = app.from_game(sample_game())
  let #(state, effect) = app.update(state, event.PageDown)
  assert state.game.current_index == 4
  assert effect == Render
}

pub fn replay_page_up_skips_backward_10_turns_test() {
  let state = app.from_game(long_game())
  let state = AppState(..state, game: game.goto_end(state.game))
  let #(state, effect) = app.update(state, event.PageUp)
  // 20 plies back from end (20) = 0
  assert state.game.current_index == 0
  assert effect == Render
}

pub fn replay_page_up_clamps_to_start_test() {
  let state = app.from_game(sample_game())
  let #(state, _) = app.update(state, event.RightArrow)
  let #(state, effect) = app.update(state, event.PageUp)
  assert state.game.current_index == 0
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

// --- GameBrowser: entering ---

pub fn replay_b_enters_browser_test() {
  let state = app.from_game(sample_game())
  let #(state, effect) = app.update(state, event.Char("b"))
  assert state.mode == GameBrowser
  let assert option.Some(browser) = state.browser
  assert browser.phase == UsernameInput
  assert effect == Render
}

pub fn freeplay_b_enters_browser_test() {
  let state = app.new()
  let #(state, effect) = app.update(state, event.Char("b"))
  assert state.mode == GameBrowser
  let assert option.Some(browser) = state.browser
  assert browser.phase == UsernameInput
  assert effect == Render
}

pub fn b_with_saved_username_skips_to_fetch_test() {
  let state =
    app.AppState(..app.new(), last_username: option.Some("hikaru"))
  let #(state, effect) = app.update(state, event.Char("b"))
  assert state.mode == GameBrowser
  let assert option.Some(browser) = state.browser
  assert browser.phase == LoadingArchives
  assert browser.username == "hikaru"
  assert browser.input_buffer == "hikaru"
  assert effect == FetchArchives("hikaru")
}

pub fn username_submit_saves_last_username_test() {
  let state = app.new()
  let #(state, _) = app.update(state, event.Char("b"))
  let #(state, _) = app.update(state, event.Char("h"))
  let #(state, _) = app.update(state, event.Char("i"))
  let #(state, _) = app.update(state, event.Enter)
  assert state.last_username == option.Some("hi")
}

// --- UsernameInput phase ---

fn browser_state() -> AppState {
  let state = app.new()
  let #(state, _) = app.update(state, event.Char("b"))
  state
}

pub fn username_typing_appends_test() {
  let state = browser_state()
  let #(state, effect) = app.update(state, event.Char("h"))
  let assert option.Some(browser) = state.browser
  assert browser.input_buffer == "h"
  assert effect == Render
  let #(state, _) = app.update(state, event.Char("i"))
  let assert option.Some(browser) = state.browser
  assert browser.input_buffer == "hi"
}

pub fn username_backspace_removes_test() {
  let state = browser_state()
  let #(state, _) = app.update(state, event.Char("h"))
  let #(state, _) = app.update(state, event.Char("i"))
  let #(state, effect) = app.update(state, event.Backspace)
  let assert option.Some(browser) = state.browser
  assert browser.input_buffer == "h"
  assert effect == Render
}

pub fn username_escape_exits_browser_test() {
  let state = browser_state()
  let #(state, effect) = app.update(state, event.Esc)
  assert state.mode == FreePlay
  assert state.browser == option.None
  assert effect == Render
}

pub fn username_enter_submits_test() {
  let state = browser_state()
  let #(state, _) = app.update(state, event.Char("h"))
  let #(state, _) = app.update(state, event.Char("i"))
  let #(state, effect) = app.update(state, event.Enter)
  let assert option.Some(browser) = state.browser
  assert browser.phase == LoadingArchives
  assert browser.username == "hi"
  assert effect == FetchArchives("hi")
}

pub fn username_enter_empty_is_noop_test() {
  let state = browser_state()
  let #(_, effect) = app.update(state, event.Enter)
  assert effect == None
}

// --- on_fetch_result: archives ---

fn loading_archives_state() -> AppState {
  let state = browser_state()
  let #(state, _) = app.update(state, event.Char("h"))
  let #(state, _) = app.update(state, event.Char("i"))
  let #(state, _) = app.update(state, event.Enter)
  state
}

pub fn archives_success_shows_list_test() {
  let state = loading_archives_state()
  let result =
    app.ArchivesResult(Ok(api.ArchivesResponse(archives: [
      "https://api.chess.com/pub/player/hi/games/2024/01",
      "https://api.chess.com/pub/player/hi/games/2024/02",
    ])))
  let #(state, effect) = app.on_fetch_result(state, result)
  let assert option.Some(browser) = state.browser
  assert browser.phase == ArchiveList
  // Reversed — newest first
  assert browser.archive_cursor == 0
  let assert [first, ..] = browser.archives
  assert first == "https://api.chess.com/pub/player/hi/games/2024/02"
  assert effect == Render
}

pub fn archives_empty_shows_list_test() {
  let state = loading_archives_state()
  let result = app.ArchivesResult(Ok(api.ArchivesResponse(archives: [])))
  let #(state, effect) = app.on_fetch_result(state, result)
  let assert option.Some(browser) = state.browser
  assert browser.phase == ArchiveList
  assert browser.archives == []
  assert effect == Render
}

pub fn archives_error_shows_error_test() {
  let state = loading_archives_state()
  let result = app.ArchivesResult(Error(api.HttpError("network failure")))
  let #(state, effect) = app.on_fetch_result(state, result)
  let assert option.Some(browser) = state.browser
  assert browser.phase == LoadError
  assert browser.error == "HTTP error: network failure"
  assert effect == Render
}

// --- ArchiveList phase ---

fn archive_list_state() -> AppState {
  let state = loading_archives_state()
  let result =
    app.ArchivesResult(Ok(api.ArchivesResponse(archives: [
      "https://api.chess.com/pub/player/hi/games/2024/01",
      "https://api.chess.com/pub/player/hi/games/2024/02",
      "https://api.chess.com/pub/player/hi/games/2024/03",
    ])))
  let #(state, _) = app.on_fetch_result(state, result)
  state
}

pub fn archive_list_down_moves_cursor_test() {
  let state = archive_list_state()
  let #(state, effect) = app.update(state, event.DownArrow)
  let assert option.Some(browser) = state.browser
  assert browser.archive_cursor == 1
  assert effect == Render
}

pub fn archive_list_up_clamps_at_zero_test() {
  let state = archive_list_state()
  let #(state, effect) = app.update(state, event.UpArrow)
  let assert option.Some(browser) = state.browser
  assert browser.archive_cursor == 0
  assert effect == Render
}

pub fn archive_list_enter_fetches_games_test() {
  let state = archive_list_state()
  let #(state, _) = app.update(state, event.DownArrow)
  let #(state, effect) = app.update(state, event.Enter)
  let assert option.Some(browser) = state.browser
  assert browser.phase == LoadingGames
  // Cursor at 1, archives are reversed so index 1 is the middle one
  assert effect
    == FetchGames("https://api.chess.com/pub/player/hi/games/2024/02")
}

pub fn archive_list_escape_goes_to_username_test() {
  let state = archive_list_state()
  let #(state, effect) = app.update(state, event.Esc)
  let assert option.Some(browser) = state.browser
  assert browser.phase == UsernameInput
  assert effect == Render
}

pub fn archive_list_q_exits_browser_test() {
  let state = archive_list_state()
  let #(state, effect) = app.update(state, event.Char("q"))
  assert state.mode == FreePlay
  assert state.browser == option.None
  assert effect == Render
}

// --- on_fetch_result: games ---

fn sample_game_summary(pgn_str: String) -> api.GameSummary {
  api.GameSummary(
    url: "https://chess.com/game/123",
    pgn: pgn_str,
    time_control: "180",
    time_class: "blitz",
    end_time: 1_700_000_000,
    rated: True,
    white: api.PlayerInfo("hi", 1500, "win"),
    black: api.PlayerInfo("opponent", 1400, "resigned"),
    accuracy_white: 0.0,
    accuracy_black: 0.0,
  )
}

fn loading_games_state() -> AppState {
  let state = archive_list_state()
  // Press enter to select first archive
  let #(state, _) = app.update(state, event.Enter)
  state
}

pub fn games_success_shows_list_test() {
  let state = loading_games_state()
  let result =
    app.GamesResult(Ok(api.GamesResponse(games: [
      sample_game_summary("1. e4 e5"),
      sample_game_summary("1. d4 d5"),
    ])))
  let #(state, effect) = app.on_fetch_result(state, result)
  let assert option.Some(browser) = state.browser
  assert browser.phase == GameList
  assert browser.game_cursor == 0
  assert list.length(browser.games) == 2
  assert effect == Render
}

pub fn games_error_shows_error_test() {
  let state = loading_games_state()
  let result = app.GamesResult(Error(api.JsonError("bad json")))
  let #(state, effect) = app.on_fetch_result(state, result)
  let assert option.Some(browser) = state.browser
  assert browser.phase == LoadError
  assert browser.error == "JSON error: bad json"
  assert effect == Render
}

// --- GameList phase ---

fn game_list_state() -> AppState {
  let state = loading_games_state()
  let result =
    app.GamesResult(Ok(api.GamesResponse(games: [
      sample_game_summary("1. e4 e5 2. Nf3 Nc6"),
      sample_game_summary("1. d4 d5 2. c4"),
      sample_game_summary("1. e4 c5"),
    ])))
  let #(state, _) = app.on_fetch_result(state, result)
  state
}

pub fn game_list_down_moves_cursor_test() {
  let state = game_list_state()
  let #(state, effect) = app.update(state, event.DownArrow)
  let assert option.Some(browser) = state.browser
  assert browser.game_cursor == 1
  assert effect == Render
}

pub fn game_list_up_clamps_at_zero_test() {
  let state = game_list_state()
  let #(state, effect) = app.update(state, event.UpArrow)
  let assert option.Some(browser) = state.browser
  assert browser.game_cursor == 0
  assert effect == Render
}

pub fn game_list_enter_loads_game_test() {
  let state = game_list_state()
  let #(state, effect) = app.update(state, event.Enter)
  assert state.mode == GameReplay
  assert state.browser == option.None
  // Game should have moves from the selected PGN
  assert state.game.current_index == 0
  assert state.game.moves != []
  assert effect == Render
}

pub fn game_list_enter_white_keeps_board_orientation_test() {
  // User "hi" played as white — board stays from white's perspective
  let state = game_list_state()
  let #(state, _) = app.update(state, event.Enter)
  assert state.from_white == True
}

pub fn game_list_enter_black_flips_board_test() {
  // User "hi" played as black — board should flip to black's perspective
  let state = loading_games_state()
  let game_as_black =
    api.GameSummary(
      ..sample_game_summary("1. e4 e5"),
      white: api.PlayerInfo("opponent", 1500, "resigned"),
      black: api.PlayerInfo("hi", 1400, "win"),
    )
  let result =
    app.GamesResult(Ok(api.GamesResponse(games: [game_as_black])))
  let #(state, _) = app.on_fetch_result(state, result)
  let #(state, _) = app.update(state, event.Enter)
  assert state.mode == GameReplay
  assert state.from_white == False
}

pub fn game_list_enter_bad_pgn_shows_error_test() {
  // Create a game list with invalid PGN
  let state = loading_games_state()
  let result =
    app.GamesResult(Ok(api.GamesResponse(games: [
      sample_game_summary("not valid pgn!!!"),
    ])))
  let #(state, _) = app.on_fetch_result(state, result)
  let #(state, effect) = app.update(state, event.Enter)
  let assert option.Some(browser) = state.browser
  assert browser.phase == LoadError
  assert browser.error == "Failed to parse PGN"
  assert effect == Render
}

pub fn game_list_escape_goes_to_archives_test() {
  let state = game_list_state()
  let #(state, effect) = app.update(state, event.Esc)
  let assert option.Some(browser) = state.browser
  assert browser.phase == ArchiveList
  assert effect == Render
}

pub fn game_list_q_exits_browser_test() {
  let state = game_list_state()
  let #(state, effect) = app.update(state, event.Char("q"))
  assert state.mode == FreePlay
  assert state.browser == option.None
  assert effect == Render
}

// --- LoadError phase ---

pub fn load_error_escape_goes_to_username_test() {
  let state = loading_archives_state()
  let result = app.ArchivesResult(Error(api.HttpError("fail")))
  let #(state, _) = app.on_fetch_result(state, result)
  let #(state, effect) = app.update(state, event.Esc)
  let assert option.Some(browser) = state.browser
  assert browser.phase == UsernameInput
  assert browser.error == ""
  assert effect == Render
}

pub fn load_error_q_exits_browser_test() {
  let state = loading_archives_state()
  let result = app.ArchivesResult(Error(api.HttpError("fail")))
  let #(state, _) = app.on_fetch_result(state, result)
  let #(state, effect) = app.update(state, event.Char("q"))
  assert state.mode == FreePlay
  assert state.browser == option.None
  assert effect == Render
}

// --- Analysis: 'r' key starts analysis ---

pub fn replay_r_starts_analysis_test() {
  let state = app.from_game(sample_game())
  let #(state, effect) = app.update(state, event.Char("r"))
  assert effect == AnalyzeGame
  assert state.analysis_progress == option.Some(#(0, 4))
}

pub fn replay_r_on_empty_game_is_noop_test() {
  // FreePlay with no moves — r should do nothing
  let state = app.new()
  let state = AppState(..state, mode: GameReplay)
  let #(_, effect) = app.update(state, event.Char("r"))
  assert effect == None
}

pub fn on_analysis_result_stores_analysis_test() {
  let state = app.from_game(sample_game())
  let #(state, _) = app.update(state, event.Char("r"))
  let ga =
    GameAnalysis(evaluations: [Centipawns(0), Centipawns(20)], move_analyses: [])
  let #(state, effect) = app.on_analysis_result(state, ga)
  assert state.analysis == option.Some(ga)
  assert state.analysis_progress == option.None
  assert effect == Render
}

pub fn navigation_preserves_analysis_test() {
  let state = app.from_game(sample_game())
  let ga =
    GameAnalysis(evaluations: [Centipawns(0), Centipawns(20)], move_analyses: [])
  let state = AppState(..state, analysis: option.Some(ga))
  let #(state, _) = app.update(state, event.RightArrow)
  assert state.analysis == option.Some(ga)
  assert state.game.current_index == 1
}

pub fn new_game_from_browser_clears_analysis_test() {
  // Load a game with analysis, then load a new game from browser
  let state = app.from_game(sample_game())
  let ga =
    GameAnalysis(evaluations: [Centipawns(0), Centipawns(20)], move_analyses: [])
  let state = AppState(..state, analysis: option.Some(ga))
  // Simulate loading a new game from the browser game list
  let state = game_list_state_from(state)
  let #(state, _) = app.update(state, event.Enter)
  assert state.mode == GameReplay
  assert state.analysis == option.None
  assert state.analysis_progress == option.None
}

fn game_list_state_from(base: AppState) -> AppState {
  // Set up browser in GameList phase with a valid game
  let browser =
    app.BrowserState(
      username: "hi",
      input_buffer: "hi",
      archives: [],
      archive_cursor: 0,
      games: [sample_game_summary("1. d4 d5")],
      game_cursor: 0,
      phase: GameList,
      error: "",
    )
  AppState(..base, mode: GameBrowser, browser: option.Some(browser))
}
