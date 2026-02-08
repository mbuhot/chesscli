//// Elm-style state machine for the TUI application.
//// All input handling is a pure update(state, key) -> #(state, effect)
//// function, keeping side effects at the boundary in chesscli.gleam.

import chesscli/chess/color
import chesscli/chess/game.{type Game}
import chesscli/chess/move.{type Move}
import chesscli/engine/uci
import chesscli/chesscom/api.{
  type ApiError, type ArchivesResponse, type GameSummary, type GamesResponse,
}
import chesscli/engine/analysis.{type GameAnalysis}
import chesscli/puzzle/puzzle.{type PuzzlePhase, type TrainingSession}
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
  /// Browsing chess.com game archives.
  GameBrowser
  /// Solving puzzles extracted from game analysis.
  PuzzleTraining
}

/// Which sub-screen the game browser is showing.
pub type BrowserPhase {
  UsernameInput
  LoadingArchives
  ArchiveList
  LoadingGames
  GameList
  LoadError
}

/// State for the chess.com game browser.
pub type BrowserState {
  BrowserState(
    username: String,
    input_buffer: String,
    archives: List(String),
    archive_cursor: Int,
    games: List(GameSummary),
    game_cursor: Int,
    phase: BrowserPhase,
    error: String,
  )
}

/// Results from async chess.com API fetches, fed back into the state machine.
pub type FetchResult {
  ArchivesResult(Result(ArchivesResponse, ApiError))
  GamesResult(Result(GamesResponse, ApiError))
}

/// The complete application state, designed for pure update functions.
pub type AppState {
  AppState(
    game: Game,
    mode: Mode,
    from_white: Bool,
    input_buffer: String,
    input_error: String,
    browser: Option(BrowserState),
    last_username: Option(String),
    analysis: Option(GameAnalysis),
    analysis_progress: Option(#(Int, Int)),
    deep_analysis_index: Option(Int),
    puzzle_session: Option(TrainingSession),
    puzzle_phase: PuzzlePhase,
    puzzle_feedback: String,
    puzzle_hint_used: Bool,
  )
}

/// Side effects that the event loop should perform after an update.
pub type Effect {
  Render
  Quit
  None
  FetchArchives(String)
  FetchGames(String)
  AnalyzeGame
  ContinueDeepAnalysis
  CancelDeepAnalysis
  StartPuzzles
  LoadCachedPuzzles
  SavePuzzles
  ScanForPuzzles
  RefreshPuzzles
}

/// Create a new app state in FreePlay mode with a fresh game.
pub fn new() -> AppState {
  AppState(
    game: game.new(),
    mode: FreePlay,
    from_white: True,
    input_buffer: "",
    input_error: "",
    browser: option.None,
    last_username: option.None,
    analysis: option.None,
    analysis_progress: option.None,
    deep_analysis_index: option.None,
    puzzle_session: option.None,
    puzzle_phase: puzzle.Solving,
    puzzle_feedback: "",
    puzzle_hint_used: False,
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
    browser: option.None,
    last_username: option.None,
    analysis: option.None,
    analysis_progress: option.None,
    deep_analysis_index: option.None,
    puzzle_session: option.None,
    puzzle_phase: puzzle.Solving,
    puzzle_feedback: "",
    puzzle_hint_used: False,
  )
}

/// Pure state transition: given current state and a key press, return
/// the new state and any side effect to perform.
pub fn update(state: AppState, key: KeyCode) -> #(AppState, Effect) {
  case state.mode {
    GameReplay -> update_game_replay(state, key)
    FreePlay -> update_free_play(state, key)
    MoveInput -> update_move_input(state, key)
    GameBrowser -> update_game_browser(state, key)
    PuzzleTraining -> update_puzzle_training(state, key)
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
    event.DownArrow -> #(AppState(..state, game: game.skip(state.game, 2)), Render)
    event.UpArrow -> #(AppState(..state, game: game.skip(state.game, -2)), Render)
    event.PageDown -> #(AppState(..state, game: game.skip(state.game, 20)), Render)
    event.PageUp -> #(AppState(..state, game: game.skip(state.game, -20)), Render)
    event.Home -> #(AppState(..state, game: game.goto_start(state.game)), Render)
    event.End -> #(AppState(..state, game: game.goto_end(state.game)), Render)
    event.Char("f") -> #(AppState(..state, from_white: !state.from_white), Render)
    event.Char("r") -> start_analysis(state)
    event.Char("p") -> start_puzzles(state)
    event.Char("b") -> enter_browser(state)
    event.Char("q") -> #(state, Quit)
    event.Char("/") -> enter_move_input(state)
    event.Char(c) -> try_auto_input(state, c)
    _ -> #(state, None)
  }
}

fn start_analysis(state: AppState) -> #(AppState, Effect) {
  let total = list.length(state.game.moves)
  case total > 0 {
    True ->
      case state.deep_analysis_index {
        option.Some(_) -> #(
          AppState(
            ..state,
            analysis_progress: option.Some(#(0, total)),
            deep_analysis_index: option.None,
          ),
          CancelDeepAnalysis,
        )
        option.None -> #(
          AppState(..state, analysis_progress: option.Some(#(0, total))),
          AnalyzeGame,
        )
      }
    False -> #(state, None)
  }
}

fn start_puzzles(state: AppState) -> #(AppState, Effect) {
  case state.analysis {
    option.Some(_) -> #(state, StartPuzzles)
    option.None -> #(state, LoadCachedPuzzles)
  }
}

/// Enter puzzle training mode with a prepared session.
/// Sets the board perspective to match the first puzzle's player color.
pub fn enter_puzzle_mode(
  state: AppState,
  session: TrainingSession,
) -> AppState {
  let from_white = case puzzle.current_puzzle(session) {
    option.Some(p) -> p.player_color == color.White
    option.None -> state.from_white
  }
  AppState(
    ..state,
    mode: PuzzleTraining,
    puzzle_session: option.Some(session),
    puzzle_phase: puzzle.Solving,
    puzzle_feedback: "",
    puzzle_hint_used: False,
    input_buffer: "",
    input_error: "",
    from_white: from_white,
  )
}

fn puzzle_perspective(session: TrainingSession) -> Bool {
  case puzzle.current_puzzle(session) {
    option.Some(p) -> p.player_color == color.White
    option.None -> True
  }
}

fn update_puzzle_training(
  state: AppState,
  key: KeyCode,
) -> #(AppState, Effect) {
  let assert option.Some(session) = state.puzzle_session
  case state.puzzle_phase {
    puzzle.Correct | puzzle.Revealed -> update_puzzle_after_result(state, session, key)
    _ -> update_puzzle_solving(state, session, key)
  }
}

fn update_puzzle_solving(
  state: AppState,
  session: TrainingSession,
  key: KeyCode,
) -> #(AppState, Effect) {
  case key {
    event.Esc | event.Char("\u{001b}") ->
      case state.input_buffer {
        "" -> exit_puzzle_mode(state)
        _ -> #(
          AppState(..state, input_buffer: "", input_error: ""),
          Render,
        )
      }
    event.Char("q") ->
      case state.input_buffer {
        "" -> exit_puzzle_mode(state)
        _ -> #(
          AppState(..state, input_buffer: state.input_buffer <> "q"),
          Render,
        )
      }
    event.Char("h") ->
      case state.input_buffer {
        "" -> advance_hint(state)
        _ -> #(
          AppState(..state, input_buffer: state.input_buffer <> "h"),
          Render,
        )
      }
    event.Char("r") ->
      case state.input_buffer {
        "" -> reveal_solution(state, session)
        _ -> #(
          AppState(..state, input_buffer: state.input_buffer <> "r"),
          Render,
        )
      }
    event.Enter | event.Char("\r") -> check_puzzle_answer(state, session)
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

fn update_puzzle_after_result(
  state: AppState,
  session: TrainingSession,
  key: KeyCode,
) -> #(AppState, Effect) {
  case key {
    event.Char("n") | event.Char("\r") | event.Enter -> {
      // Update solve_count: clean solve (Correct, no hints) increments, else resets
      let clean = state.puzzle_phase == puzzle.Correct && !state.puzzle_hint_used
      let updated_session = puzzle.update_solve_count(session, clean)
      let new_session = puzzle.record_result(updated_session, state.puzzle_phase)
      case puzzle.next_puzzle(new_session) {
        Ok(s) -> #(
          AppState(
            ..state,
            puzzle_session: option.Some(s),
            puzzle_phase: puzzle.Solving,
            puzzle_feedback: "",
            puzzle_hint_used: False,
            input_buffer: "",
            input_error: "",
            from_white: puzzle_perspective(s),
          ),
          SavePuzzles,
        )
        Error(_) -> {
          // All puzzles done — show stats
          let #(total, solved, revealed) = puzzle.stats(new_session)
          let feedback =
            "Done! "
            <> int.to_string(solved)
            <> "/"
            <> int.to_string(total)
            <> " solved, "
            <> int.to_string(revealed)
            <> " revealed"
          #(
            AppState(
              ..state,
              puzzle_session: option.Some(new_session),
              puzzle_feedback: feedback,
            ),
            SavePuzzles,
          )
        }
      }
    }
    event.Char("N") -> {
      case puzzle.prev_puzzle(session) {
        Ok(s) -> #(
          AppState(
            ..state,
            puzzle_session: option.Some(s),
            puzzle_phase: puzzle.Solving,
            puzzle_feedback: "",
            input_buffer: "",
            from_white: puzzle_perspective(s),
          ),
          Render,
        )
        Error(_) -> #(state, None)
      }
    }
    event.Char("r") ->
      case state.puzzle_phase {
        puzzle.Correct -> reveal_solution(state, session)
        _ -> #(state, None)
      }
    event.Esc | event.Char("\u{001b}") -> #(
      AppState(..state, puzzle_phase: puzzle.Solving, puzzle_feedback: "", input_buffer: ""),
      Render,
    )
    event.Char("q") -> exit_puzzle_mode(state)
    _ -> #(state, None)
  }
}

fn advance_hint(state: AppState) -> #(AppState, Effect) {
  let new_phase = case state.puzzle_phase {
    puzzle.Solving | puzzle.Incorrect -> puzzle.HintPiece
    puzzle.HintPiece -> puzzle.HintSquare
    other -> other
  }
  #(AppState(..state, puzzle_phase: new_phase, puzzle_hint_used: True), Render)
}

fn reveal_solution(
  state: AppState,
  session: TrainingSession,
) -> #(AppState, Effect) {
  let assert option.Some(p) = puzzle.current_puzzle(session)
  let solution_san = puzzle.format_uci_as_san(p.fen, p.solution_uci)
  let feedback =
    "Best: " <> solution_san <> " (eval " <> p.eval_before <> ")"
  #(
    AppState(..state, puzzle_phase: puzzle.Revealed, puzzle_feedback: feedback),
    Render,
  )
}

fn check_puzzle_answer(
  state: AppState,
  session: TrainingSession,
) -> #(AppState, Effect) {
  case state.input_buffer {
    "" -> #(state, None)
    buffer -> {
      let assert option.Some(p) = puzzle.current_puzzle(session)
      case parse_puzzle_input(buffer, p) {
        Ok(uci) ->
          case puzzle.check_move(p, uci) {
            True -> #(
              AppState(
                ..state,
                puzzle_phase: puzzle.Correct,
                puzzle_feedback: "Correct!",
                input_buffer: "",
                input_error: "",
              ),
              Render,
            )
            False -> #(
              AppState(
                ..state,
                puzzle_phase: puzzle.Incorrect,
                puzzle_feedback: "Not the best move.",
                input_buffer: "",
                input_error: "",
              ),
              Render,
            )
          }
        Error(err) -> #(
          AppState(..state, input_buffer: "", input_error: err),
          Render,
        )
      }
    }
  }
}

import chesscli/chess/fen

/// Parse puzzle input as SAN then fall back to UCI. Returns the UCI string
/// on success, or an error message describing why parsing failed.
fn parse_puzzle_input(
  buffer: String,
  p: puzzle.Puzzle,
) -> Result(String, String) {
  case fen.parse(p.fen) {
    Ok(pos) ->
      case san.parse(buffer, pos) {
        Ok(m) -> Ok(move.to_uci(m))
        Error(san.AmbiguousMove(_)) ->
          Error("Ambiguous: " <> buffer <> " — add file/rank to disambiguate")
        Error(san.NoMatchingMove(_)) ->
          // Fall back to UCI interpretation
          case move.from_uci(buffer) {
            Ok(_) -> Ok(buffer)
            Error(_) -> Error("No legal move: " <> buffer)
          }
        Error(san.InvalidSan(_)) ->
          case move.from_uci(buffer) {
            Ok(_) -> Ok(buffer)
            Error(_) -> Error("Invalid move: " <> buffer)
          }
      }
    Error(_) -> Error("Invalid position")
  }
}

fn exit_puzzle_mode(state: AppState) -> #(AppState, Effect) {
  #(
    AppState(
      ..state,
      mode: GameReplay,
      puzzle_session: option.None,
      puzzle_phase: puzzle.Solving,
      puzzle_feedback: "",
      input_buffer: "",
      input_error: "",
    ),
    Render,
  )
}

fn update_free_play(state: AppState, key: KeyCode) -> #(AppState, Effect) {
  case key {
    event.Char("u") ->
      case game.backward(state.game) {
        Ok(g) -> #(AppState(..state, game: g), Render)
        Error(_) -> #(state, None)
      }
    event.Char("f") -> #(AppState(..state, from_white: !state.from_white), Render)
    event.Char("p") -> #(state, LoadCachedPuzzles)
    event.Char("b") -> enter_browser(state)
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

import chesscli/chess/pgn
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
    // Files (b excluded — used for browser shortcut)
    "a" | "c" | "d" | "e" | "g" | "h" -> True
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

fn enter_browser(state: AppState) -> #(AppState, Effect) {
  case state.last_username {
    option.Some(username) -> {
      let browser =
        BrowserState(
          username: username,
          input_buffer: username,
          archives: [],
          archive_cursor: 0,
          games: [],
          game_cursor: 0,
          phase: LoadingArchives,
          error: "",
        )
      #(
        AppState(..state, mode: GameBrowser, browser: option.Some(browser)),
        FetchArchives(username),
      )
    }
    option.None -> {
      let browser =
        BrowserState(
          username: "",
          input_buffer: "",
          archives: [],
          archive_cursor: 0,
          games: [],
          game_cursor: 0,
          phase: UsernameInput,
          error: "",
        )
      #(
        AppState(..state, mode: GameBrowser, browser: option.Some(browser)),
        Render,
      )
    }
  }
}

fn update_game_browser(state: AppState, key: KeyCode) -> #(AppState, Effect) {
  let assert option.Some(browser) = state.browser
  case browser.phase {
    UsernameInput -> update_username_input(state, browser, key)
    ArchiveList -> update_archive_list(state, browser, key)
    GameList -> update_game_list(state, browser, key)
    LoadError -> update_load_error(state, browser, key)
    LoadingArchives | LoadingGames -> #(state, None)
  }
}

fn update_username_input(
  state: AppState,
  browser: BrowserState,
  key: KeyCode,
) -> #(AppState, Effect) {
  case key {
    event.Esc | event.Char("\u{001b}") -> exit_browser(state)
    event.Enter | event.Char("\r") ->
      case browser.input_buffer {
        "" -> #(state, None)
        username -> {
          let new_browser =
            BrowserState(
              ..browser,
              username: username,
              phase: LoadingArchives,
            )
          #(
            AppState(
              ..state,
              browser: option.Some(new_browser),
              last_username: option.Some(username),
            ),
            FetchArchives(username),
          )
        }
      }
    event.Backspace | event.Char("\u{007f}") -> {
      let new_buffer = string.drop_end(browser.input_buffer, 1)
      let new_browser = BrowserState(..browser, input_buffer: new_buffer)
      #(AppState(..state, browser: option.Some(new_browser)), Render)
    }
    event.Char(c) -> {
      let new_browser =
        BrowserState(..browser, input_buffer: browser.input_buffer <> c)
      #(AppState(..state, browser: option.Some(new_browser)), Render)
    }
    _ -> #(state, None)
  }
}

fn update_archive_list(
  state: AppState,
  browser: BrowserState,
  key: KeyCode,
) -> #(AppState, Effect) {
  let max_cursor = list.length(browser.archives) - 1
  case key {
    event.DownArrow | event.Char("j") -> {
      let new_cursor = int.min(browser.archive_cursor + 1, max_cursor)
      let new_browser = BrowserState(..browser, archive_cursor: new_cursor)
      #(AppState(..state, browser: option.Some(new_browser)), Render)
    }
    event.UpArrow | event.Char("k") -> {
      let new_cursor = int.max(browser.archive_cursor - 1, 0)
      let new_browser = BrowserState(..browser, archive_cursor: new_cursor)
      #(AppState(..state, browser: option.Some(new_browser)), Render)
    }
    event.Enter | event.Char("\r") -> {
      let assert option.Some(url) =
        list_at(browser.archives, browser.archive_cursor)
      let new_browser = BrowserState(..browser, phase: LoadingGames)
      #(
        AppState(..state, browser: option.Some(new_browser)),
        FetchGames(url),
      )
    }
    event.Esc | event.Char("\u{001b}") -> {
      let new_browser =
        BrowserState(..browser, phase: UsernameInput, archives: [], archive_cursor: 0)
      #(AppState(..state, browser: option.Some(new_browser)), Render)
    }
    event.Char("q") -> exit_browser(state)
    _ -> #(state, None)
  }
}

fn update_game_list(
  state: AppState,
  browser: BrowserState,
  key: KeyCode,
) -> #(AppState, Effect) {
  let max_cursor = list.length(browser.games) - 1
  case key {
    event.DownArrow | event.Char("j") -> {
      let new_cursor = int.min(browser.game_cursor + 1, max_cursor)
      let new_browser = BrowserState(..browser, game_cursor: new_cursor)
      #(AppState(..state, browser: option.Some(new_browser)), Render)
    }
    event.UpArrow | event.Char("k") -> {
      let new_cursor = int.max(browser.game_cursor - 1, 0)
      let new_browser = BrowserState(..browser, game_cursor: new_cursor)
      #(AppState(..state, browser: option.Some(new_browser)), Render)
    }
    event.Enter | event.Char("\r") -> {
      let assert option.Some(game_summary) =
        list_at(browser.games, browser.game_cursor)
      case pgn.parse(game_summary.pgn) {
        Ok(pgn_game) -> {
          let g = game.from_pgn(pgn_game)
          let from_white =
            string.lowercase(game_summary.black.username)
            != string.lowercase(browser.username)
          #(
            AppState(
              ..state,
              game: g,
              mode: GameReplay,
              from_white: from_white,
              browser: option.None,
              analysis: option.None,
              analysis_progress: option.None,
              deep_analysis_index: option.None,
            ),
            Render,
          )
        }
        Error(_) -> {
          let new_browser =
            BrowserState(..browser, phase: LoadError, error: "Failed to parse PGN")
          #(AppState(..state, browser: option.Some(new_browser)), Render)
        }
      }
    }
    event.Esc | event.Char("\u{001b}") -> {
      let new_browser =
        BrowserState(..browser, phase: ArchiveList, games: [], game_cursor: 0)
      #(AppState(..state, browser: option.Some(new_browser)), Render)
    }
    event.Char("q") -> exit_browser(state)
    _ -> #(state, None)
  }
}

fn update_load_error(
  state: AppState,
  browser: BrowserState,
  key: KeyCode,
) -> #(AppState, Effect) {
  case key {
    event.Esc | event.Char("\u{001b}") -> {
      let new_browser = BrowserState(..browser, phase: UsernameInput, error: "")
      #(AppState(..state, browser: option.Some(new_browser)), Render)
    }
    event.Char("q") -> exit_browser(state)
    _ -> #(state, None)
  }
}

fn exit_browser(state: AppState) -> #(AppState, Effect) {
  #(AppState(..state, mode: FreePlay, browser: option.None), Render)
}

/// Store the shallow analysis result and begin deep analysis pass.
/// Skips positions that are already settled (Best moves, overwhelming evals).
pub fn on_analysis_result(
  state: AppState,
  result: GameAnalysis,
) -> #(AppState, Effect) {
  let total = list.length(result.evaluations)
  let first_idx = next_deep_index(0, total, result)
  case first_idx >= total {
    True ->
      // All positions are settled — no deep pass needed
      #(
        AppState(
          ..state,
          analysis: option.Some(result),
          analysis_progress: option.None,
          deep_analysis_index: option.None,
        ),
        Render,
      )
    False ->
      #(
        AppState(
          ..state,
          analysis: option.Some(result),
          analysis_progress: option.None,
          deep_analysis_index: option.Some(first_idx),
        ),
        ContinueDeepAnalysis,
      )
  }
}

/// Update a single position's evaluation during deep analysis.
/// Increments the deep analysis index and continues, or completes when done.
pub fn on_deep_eval_update(
  state: AppState,
  position_index: Int,
  new_score: uci.Score,
  new_best_uci: String,
  new_best_pv: List(String),
) -> #(AppState, Effect) {
  let assert option.Some(ga) = state.analysis
  let move_ucis = list.map(state.game.moves, move.to_uci)
  let active_colors =
    list.map(
      list.take(state.game.positions, list.length(state.game.moves)),
      fn(pos) { pos.active_color },
    )
  let updated_ga =
    analysis.update_evaluation(
      ga,
      position_index,
      new_score,
      new_best_uci,
      new_best_pv,
      move_ucis,
      active_colors,
    )
  let total_positions = list.length(state.game.positions)
  let next_idx = next_deep_index(position_index + 1, total_positions, updated_ga)
  case next_idx >= total_positions {
    True -> #(
      AppState(
        ..state,
        analysis: option.Some(updated_ga),
        deep_analysis_index: option.None,
      ),
      Render,
    )
    False -> #(
      AppState(
        ..state,
        analysis: option.Some(updated_ga),
        deep_analysis_index: option.Some(next_idx),
      ),
      ContinueDeepAnalysis,
    )
  }
}

/// Process the result of an async chess.com API fetch.
pub fn on_fetch_result(
  state: AppState,
  result: FetchResult,
) -> #(AppState, Effect) {
  let assert option.Some(browser) = state.browser
  case result {
    ArchivesResult(Ok(response)) -> {
      let archives = list.reverse(response.archives)
      let new_browser =
        BrowserState(..browser, phase: ArchiveList, archives: archives, archive_cursor: 0)
      #(AppState(..state, browser: option.Some(new_browser)), Render)
    }
    ArchivesResult(Error(err)) -> {
      let new_browser =
        BrowserState(..browser, phase: LoadError, error: api_error_to_string(err))
      #(AppState(..state, browser: option.Some(new_browser)), Render)
    }
    GamesResult(Ok(response)) -> {
      let games = list.reverse(response.games)
      let new_browser =
        BrowserState(..browser, phase: GameList, games: games, game_cursor: 0)
      #(AppState(..state, browser: option.Some(new_browser)), Render)
    }
    GamesResult(Error(err)) -> {
      let new_browser =
        BrowserState(..browser, phase: LoadError, error: api_error_to_string(err))
      #(AppState(..state, browser: option.Some(new_browser)), Render)
    }
  }
}

fn api_error_to_string(err: ApiError) -> String {
  case err {
    api.HttpError(msg) -> "HTTP error: " <> msg
    api.JsonError(msg) -> "JSON error: " <> msg
  }
}

/// Scan forward from `from` to find the next position index that should not
/// be skipped during deep analysis. Returns `total` if all remaining are skippable.
fn next_deep_index(from: Int, total: Int, ga: GameAnalysis) -> Int {
  case from >= total {
    True -> total
    False ->
      case analysis.should_skip_deep(from, ga) {
        True -> next_deep_index(from + 1, total, ga)
        False -> from
      }
  }
}

import gleam/int

fn list_at(lst: List(a), index: Int) -> Option(a) {
  case lst, index {
    [], _ -> option.None
    [head, ..], 0 -> option.Some(head)
    [_, ..tail], n if n > 0 -> list_at(tail, n - 1)
    _, _ -> option.None
  }
}
