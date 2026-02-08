import chesscli/chess/color
import chesscli/chess/game
import chesscli/chess/pgn
import chesscli/chess/square
import chesscli/chesscom/api
import chesscli/engine/analysis.{Blunder, Mistake}
import chesscli/engine/uci.{Centipawns}
import chesscli/puzzle/puzzle.{
  type Puzzle, Correct, HintPiece, HintSquare, Incorrect, Puzzle, Revealed,
  Solving,
}
import chesscli/tui/app.{
  type AppState, AnalyzeGame, AppState, ArchiveList, CancelDeepAnalysis,
  ContinueDeepAnalysis, FetchArchives, FetchGames, FreePlay, GameBrowser,
  GameList, GameReplay, LoadCachedPuzzles, LoadError, LoadingArchives,
  LoadingGames, MoveInput, None, PuzzleTraining, Quit, Render, StartPuzzles,
  UsernameInput,
}
import etch/event
import gleam/list
import gleam/string
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

pub fn free_play_p_loads_cached_puzzles_test() {
  let state = app.new()
  let #(_, effect) = app.update(state, event.Char("p"))
  assert effect == LoadCachedPuzzles
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

pub fn on_analysis_result_starts_deep_analysis_test() {
  let state = app.from_game(sample_game())
  let #(state, _) = app.update(state, event.Char("r"))
  // Build analysis with a non-Best move so deep pass is triggered
  let ga =
    analysis.build_game_analysis(
      [Centipawns(0), Centipawns(20)],
      ["e2e4"],
      ["d2d4"],
      [[]],
      [color.White],
    )
  let #(state, effect) = app.on_analysis_result(state, ga)
  assert state.analysis == option.Some(ga)
  assert state.analysis_progress == option.None
  assert state.deep_analysis_index == option.Some(0)
  assert effect == app.ContinueDeepAnalysis
}

pub fn navigation_preserves_analysis_test() {
  let state = app.from_game(sample_game())
  let ga =
    analysis.GameAnalysis(evaluations: [Centipawns(0), Centipawns(20)], move_analyses: [])
  let state = AppState(..state, analysis: option.Some(ga))
  let #(state, _) = app.update(state, event.RightArrow)
  assert state.analysis == option.Some(ga)
  assert state.game.current_index == 1
}

pub fn new_game_from_browser_clears_analysis_test() {
  // Load a game with analysis, then load a new game from browser
  let state = app.from_game(sample_game())
  let ga =
    analysis.GameAnalysis(evaluations: [Centipawns(0), Centipawns(20)], move_analyses: [])
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

// --- Deep analysis: on_deep_eval_update ---

fn analyzed_state() -> AppState {
  let state = app.from_game(sample_game())
  // Build a shallow analysis: 5 positions (4 moves), move 0 non-Best so deep pass starts
  let evals = [Centipawns(0), Centipawns(0), Centipawns(0), Centipawns(0), Centipawns(0)]
  let move_ucis = ["e2e4", "e7e5", "g1f3", "b8c6"]
  let best_ucis = ["d2d4", "e7e5", "g1f3", "b8c6"]
  let colors = [color.White, color.Black, color.White, color.Black]
  let ga = analysis.build_game_analysis(evals, move_ucis, best_ucis, [[], [], [], []], colors)
  let #(state, _) = app.on_analysis_result(state, ga)
  state
}

pub fn on_deep_eval_update_continues_test() {
  let state = analyzed_state()
  assert state.deep_analysis_index == option.Some(0)
  // Update position 0 — best differs from played, so move 0 stays non-Best
  let #(state, effect) =
    app.on_deep_eval_update(state, 0, Centipawns(10), "d2d4", [])
  assert state.deep_analysis_index == option.Some(1)
  assert effect == ContinueDeepAnalysis
}

pub fn on_deep_eval_update_completes_test() {
  let state = analyzed_state()
  // Set to last position index (4, since 5 positions total)
  let state = AppState(..state, deep_analysis_index: option.Some(4))
  let #(state, effect) =
    app.on_deep_eval_update(state, 4, Centipawns(-5), "d2d4", [])
  assert state.deep_analysis_index == option.None
  assert effect == Render
}

pub fn navigation_during_deep_analysis_preserves_index_test() {
  let state = analyzed_state()
  let state = AppState(..state, deep_analysis_index: option.Some(3))
  let #(state, _) = app.update(state, event.RightArrow)
  assert state.deep_analysis_index == option.Some(3)
  assert state.game.current_index == 1
}

pub fn new_game_clears_deep_analysis_index_test() {
  let state = analyzed_state()
  let state = AppState(..state, deep_analysis_index: option.Some(3))
  let state = game_list_state_from(state)
  let #(state, _) = app.update(state, event.Enter)
  assert state.mode == GameReplay
  assert state.deep_analysis_index == option.None
}

pub fn on_analysis_result_all_best_skips_deep_pass_test() {
  let state = app.from_game(sample_game())
  let #(state, _) = app.update(state, event.Char("r"))
  // Build analysis where all moves are Best
  let evals = [Centipawns(0), Centipawns(20), Centipawns(10), Centipawns(30), Centipawns(15)]
  let move_ucis = ["e2e4", "e7e5", "g1f3", "b8c6"]
  let best_ucis = ["e2e4", "e7e5", "g1f3", "b8c6"]
  let colors = [color.White, color.Black, color.White, color.Black]
  let ga = analysis.build_game_analysis(evals, move_ucis, best_ucis, [[], [], [], []], colors)
  // All positions are skippable → no deep pass
  let #(state, effect) = app.on_analysis_result(state, ga)
  assert state.analysis == option.Some(ga)
  assert state.deep_analysis_index == option.None
  assert effect == Render
}

pub fn on_analysis_result_with_blunder_starts_deep_test() {
  let state = app.from_game(sample_game())
  let #(state, _) = app.update(state, event.Char("r"))
  // Build analysis where move 0 is a Blunder (played e2e4, best d2d4, large eval swing)
  let evals = [Centipawns(100), Centipawns(-200), Centipawns(-180), Centipawns(-150), Centipawns(-170)]
  let move_ucis = ["e2e4", "e7e5", "g1f3", "b8c6"]
  let best_ucis = ["d2d4", "e7e5", "g1f3", "b8c6"]
  let colors = [color.White, color.Black, color.White, color.Black]
  let ga = analysis.build_game_analysis(evals, move_ucis, best_ucis, [[], [], [], []], colors)
  // Verify move 0 is indeed a Blunder
  let assert [ma0, ..] = ga.move_analyses
  assert ma0.classification == Blunder
  let #(state, effect) = app.on_analysis_result(state, ga)
  assert state.analysis == option.Some(ga)
  // Should start at position 0 (first non-skippable)
  assert state.deep_analysis_index == option.Some(0)
  assert effect == ContinueDeepAnalysis
}

pub fn on_deep_eval_update_skips_settled_positions_test() {
  // Set up: move 0 is Blunder (played e2e4, best d2d4), moves 1-3 are Best
  let state = app.from_game(sample_game())
  let evals = [Centipawns(100), Centipawns(-200), Centipawns(-180), Centipawns(-150), Centipawns(-170)]
  let move_ucis = ["e2e4", "e7e5", "g1f3", "b8c6"]
  let best_ucis = ["d2d4", "e7e5", "g1f3", "b8c6"]
  let colors = [color.White, color.Black, color.White, color.Black]
  let ga = analysis.build_game_analysis(evals, move_ucis, best_ucis, [[], [], [], []], colors)
  let #(state, _) = app.on_analysis_result(state, ga)
  // Deep analysis starts at 0 (Blunder's eval_before)
  assert state.deep_analysis_index == option.Some(0)
  // After updating position 0, keep best as "d2d4" (different from played "e2e4")
  // so move 0 stays non-Best → position 1 still needs eval
  let #(state, effect) = app.on_deep_eval_update(state, 0, Centipawns(120), "d2d4", [])
  assert effect == ContinueDeepAnalysis
  assert state.deep_analysis_index == option.Some(1)
  // After updating position 1, use "e7e5" as best so move 1 stays Best.
  // Remaining positions (2,3,4) have all-Best adjacent moves → done.
  let #(state, effect) = app.on_deep_eval_update(state, 1, Centipawns(-210), "e7e5", [])
  assert state.deep_analysis_index == option.None
  assert effect == Render
}

pub fn restart_analysis_during_deep_cancels_test() {
  let state = analyzed_state()
  let state = AppState(..state, deep_analysis_index: option.Some(3))
  let #(state, effect) = app.update(state, event.Char("r"))
  assert effect == CancelDeepAnalysis
  assert state.deep_analysis_index == option.None
  assert state.analysis_progress == option.Some(#(0, 4))
}

// --- PuzzleTraining ---

fn sample_puzzle() -> Puzzle {
  Puzzle(
    fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
    player_color: color.Black,
    solution_uci: "d7d5",
    played_uci: "e7e5",
    continuation: ["d7d5", "e4d5"],
    eval_before: "+0.2",
    eval_after: "+1.7",
    source_label: "Alice vs Bob",
    classification: Mistake,
    white_name: "Alice",
    black_name: "Bob",
    solve_count: 0,
  )
}

fn sample_puzzle_2() -> Puzzle {
  Puzzle(
    ..sample_puzzle(),
    fen: "rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1",
    solution_uci: "d7d5",
    played_uci: "e7e5",
  )
}

fn puzzle_state() -> AppState {
  let session = puzzle.new_session([sample_puzzle(), sample_puzzle_2()])
  app.enter_puzzle_mode(app.from_game(sample_game()), session)
}

// --- Mode transitions ---

pub fn replay_p_with_analysis_starts_puzzles_test() {
  let state = app.from_game(sample_game())
  let ga =
    analysis.GameAnalysis(evaluations: [Centipawns(0)], move_analyses: [])
  let state = AppState(..state, analysis: option.Some(ga))
  let #(_, effect) = app.update(state, event.Char("p"))
  assert effect == StartPuzzles
}

pub fn replay_p_without_analysis_loads_cached_test() {
  let state = app.from_game(sample_game())
  let #(_, effect) = app.update(state, event.Char("p"))
  assert effect == LoadCachedPuzzles
}

pub fn enter_puzzle_mode_sets_state_test() {
  let state = puzzle_state()
  assert state.mode == PuzzleTraining
  assert state.puzzle_phase == Solving
  assert state.puzzle_feedback == ""
  assert state.input_buffer == ""
  assert option.is_some(state.puzzle_session)
}

// --- Hint progression ---

pub fn puzzle_h_advances_to_hint_piece_test() {
  let state = puzzle_state()
  let #(state, effect) = app.update(state, event.Char("h"))
  assert state.puzzle_phase == HintPiece
  assert effect == Render
}

pub fn puzzle_h_advances_to_hint_square_test() {
  let state = puzzle_state()
  let #(state, _) = app.update(state, event.Char("h"))
  let #(state, effect) = app.update(state, event.Char("h"))
  assert state.puzzle_phase == HintSquare
  assert effect == Render
}

pub fn puzzle_h_no_further_than_hint_square_test() {
  let state = puzzle_state()
  let #(state, _) = app.update(state, event.Char("h"))
  let #(state, _) = app.update(state, event.Char("h"))
  let #(state, _) = app.update(state, event.Char("h"))
  assert state.puzzle_phase == HintSquare
}

// --- Correct / Incorrect answers ---

pub fn puzzle_correct_answer_test() {
  let state = puzzle_state()
  // Type the correct UCI move
  let #(state, _) = app.update(state, event.Char("d"))
  let #(state, _) = app.update(state, event.Char("7"))
  let #(state, _) = app.update(state, event.Char("d"))
  let #(state, _) = app.update(state, event.Char("5"))
  let #(state, effect) = app.update(state, event.Enter)
  assert state.puzzle_phase == Correct
  assert state.puzzle_feedback == "Correct!"
  assert state.input_buffer == ""
  assert effect == Render
}

pub fn puzzle_correct_san_answer_test() {
  let state = puzzle_state()
  // Type the correct SAN move
  let #(state, _) = app.update(state, event.Char("d"))
  let #(state, _) = app.update(state, event.Char("5"))
  let #(state, effect) = app.update(state, event.Enter)
  assert state.puzzle_phase == Correct
  assert state.puzzle_feedback == "Correct!"
  assert effect == Render
}

pub fn puzzle_incorrect_answer_test() {
  let state = puzzle_state()
  let #(state, _) = app.update(state, event.Char("e"))
  let #(state, _) = app.update(state, event.Char("5"))
  let #(state, effect) = app.update(state, event.Enter)
  assert state.puzzle_phase == Incorrect
  assert state.puzzle_feedback == "Not the best move."
  assert state.input_buffer == ""
  assert effect == Render
}

pub fn puzzle_ambiguous_input_shows_error_test() {
  // Position with two rooks that can go to b1: Ra1 and Rc1
  let p =
    Puzzle(
      ..sample_puzzle(),
      fen: "8/8/8/8/8/8/8/R1R4K w - - 0 1",
      player_color: color.White,
      solution_uci: "a1b1",
    )
  let session = puzzle.new_session([p])
  let state = app.enter_puzzle_mode(app.from_game(sample_game()), session)
  // Type "Rb1" — ambiguous (which rook?)
  let #(state, _) = app.update(state, event.Char("R"))
  let #(state, _) = app.update(state, event.Char("b"))
  let #(state, _) = app.update(state, event.Char("1"))
  let #(state, _) = app.update(state, event.Enter)
  // Should show ambiguity error, not "Not the best move"
  assert state.puzzle_phase == Solving
  assert string.contains(state.input_error, "Ambiguous")
}

pub fn puzzle_invalid_input_shows_error_test() {
  let state = puzzle_state()
  // Type nonsense
  let #(state, _) = app.update(state, event.Char("z"))
  let #(state, _) = app.update(state, event.Char("z"))
  let #(state, _) = app.update(state, event.Enter)
  assert state.puzzle_phase == Solving
  assert string.contains(state.input_error, "Invalid move")
}

pub fn puzzle_empty_enter_is_noop_test() {
  let state = puzzle_state()
  let #(_, effect) = app.update(state, event.Enter)
  assert effect == None
}

// --- Reveal ---

pub fn puzzle_r_reveals_solution_test() {
  let state = puzzle_state()
  let #(state, effect) = app.update(state, event.Char("r"))
  assert state.puzzle_phase == Revealed
  assert state.puzzle_feedback == "Best: d5 (eval +0.2)"
  assert effect == Render
}

pub fn puzzle_r_after_correct_reveals_solution_test() {
  let state = puzzle_state()
  // Solve correctly
  let #(state, _) = app.update(state, event.Char("d"))
  let #(state, _) = app.update(state, event.Char("5"))
  let #(state, _) = app.update(state, event.Enter)
  assert state.puzzle_phase == Correct
  // Press r to see the full line
  let #(state, effect) = app.update(state, event.Char("r"))
  assert state.puzzle_phase == Revealed
  assert effect == Render
}

pub fn puzzle_esc_from_revealed_resets_to_solving_test() {
  let state = puzzle_state()
  let #(state, _) = app.update(state, event.Char("r"))
  assert state.puzzle_phase == Revealed
  let #(state, effect) = app.update(state, event.Esc)
  assert state.puzzle_phase == Solving
  assert state.puzzle_feedback == ""
  assert effect == Render
}

pub fn puzzle_esc_from_correct_resets_to_solving_test() {
  let state = puzzle_state()
  let #(state, _) = app.update(state, event.Char("d"))
  let #(state, _) = app.update(state, event.Char("5"))
  let #(state, _) = app.update(state, event.Enter)
  assert state.puzzle_phase == Correct
  let #(state, effect) = app.update(state, event.Esc)
  assert state.puzzle_phase == Solving
  assert state.puzzle_feedback == ""
  assert effect == Render
}

// --- Navigation ---

pub fn puzzle_n_after_correct_advances_test() {
  let state = puzzle_state()
  // Solve correctly then advance
  let #(state, _) = app.update(state, event.Char("d"))
  let #(state, _) = app.update(state, event.Char("5"))
  let #(state, _) = app.update(state, event.Enter)
  assert state.puzzle_phase == Correct
  let #(state, effect) = app.update(state, event.Char("n"))
  assert state.puzzle_phase == Solving
  assert state.puzzle_feedback == ""
  assert state.input_buffer == ""
  let assert option.Some(session) = state.puzzle_session
  assert session.current_index == 1
  assert effect == app.SavePuzzles
}

pub fn puzzle_n_after_reveal_advances_test() {
  let state = puzzle_state()
  let #(state, _) = app.update(state, event.Char("r"))
  assert state.puzzle_phase == Revealed
  let #(state, effect) = app.update(state, event.Char("n"))
  assert state.puzzle_phase == Solving
  let assert option.Some(session) = state.puzzle_session
  assert session.current_index == 1
  assert effect == app.SavePuzzles
}

pub fn puzzle_shift_n_goes_back_test() {
  let state = puzzle_state()
  // Solve and advance to puzzle 2
  let #(state, _) = app.update(state, event.Char("d"))
  let #(state, _) = app.update(state, event.Char("5"))
  let #(state, _) = app.update(state, event.Enter)
  let #(state, _) = app.update(state, event.Char("n"))
  let assert option.Some(session) = state.puzzle_session
  assert session.current_index == 1
  // Now go back — need to be in Correct or Revealed to use N
  let #(state, _) = app.update(state, event.Char("r"))
  let #(state, effect) = app.update(state, event.Char("N"))
  let assert option.Some(session) = state.puzzle_session
  assert session.current_index == 0
  assert state.puzzle_phase == Solving
  assert effect == Render
}

pub fn puzzle_n_on_last_puzzle_shows_stats_test() {
  // Use a single-puzzle session
  let session = puzzle.new_session([sample_puzzle()])
  let state = app.enter_puzzle_mode(app.from_game(sample_game()), session)
  // Solve it
  let #(state, _) = app.update(state, event.Char("d"))
  let #(state, _) = app.update(state, event.Char("5"))
  let #(state, _) = app.update(state, event.Enter)
  assert state.puzzle_phase == Correct
  // Press n — should show stats since it's the last puzzle
  let #(state, effect) = app.update(state, event.Char("n"))
  assert state.puzzle_feedback == "Done! 1/1 solved, 0 revealed"
  assert effect == app.SavePuzzles
}

// --- Exit puzzle mode ---

pub fn puzzle_esc_empty_buffer_exits_test() {
  let state = puzzle_state()
  let #(state, effect) = app.update(state, event.Esc)
  assert state.mode == GameReplay
  assert state.puzzle_session == option.None
  assert state.puzzle_phase == Solving
  assert effect == Render
}

pub fn puzzle_esc_with_buffer_clears_buffer_test() {
  let state = puzzle_state()
  let #(state, _) = app.update(state, event.Char("d"))
  let #(state, effect) = app.update(state, event.Esc)
  assert state.mode == PuzzleTraining
  assert state.input_buffer == ""
  assert effect == Render
}

pub fn puzzle_q_empty_buffer_exits_test() {
  let state = puzzle_state()
  let #(state, effect) = app.update(state, event.Char("q"))
  assert state.mode == GameReplay
  assert state.puzzle_session == option.None
  assert effect == Render
}

pub fn puzzle_q_with_buffer_appends_test() {
  let state = puzzle_state()
  let #(state, _) = app.update(state, event.Char("N"))
  let #(state, _) = app.update(state, event.Char("q"))
  assert state.mode == PuzzleTraining
  assert state.input_buffer == "Nq"
}

// --- Flip board in puzzle mode ---

pub fn puzzle_f_enters_input_buffer_test() {
  let state = puzzle_state()
  let #(state, effect) = app.update(state, event.Char("f"))
  assert state.input_buffer == "f"
  assert state.from_white == False
  assert effect == Render
}

// --- Backspace in puzzle mode ---

pub fn puzzle_backspace_removes_last_char_test() {
  let state = puzzle_state()
  let #(state, _) = app.update(state, event.Char("d"))
  let #(state, _) = app.update(state, event.Char("5"))
  let #(state, effect) = app.update(state, event.Backspace)
  assert state.input_buffer == "d"
  assert effect == Render
}
