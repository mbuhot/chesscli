import chesscli/chess/game
import chesscli/chess/pgn
import chesscli/engine/analysis.{GameAnalysis}
import chesscli/engine/uci.{Centipawns}
import chesscli/tui/app.{AppState, MoveInput}
import chesscli/tui/status_bar
import etch/event
import gleam/option
import gleam/string

// --- format_status ---

pub fn format_status_replay_mode_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let state = app.from_game(game.from_pgn(pgn_game))
  let status = status_bar.format_status(state)
  assert string.contains(status, "[REPLAY]") == True
  assert string.contains(status, "White") == True
}

pub fn format_status_replay_after_move_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let g = game.from_pgn(pgn_game)
  let assert Ok(g) = game.forward(g)
  let state = AppState(..app.from_game(g), game: g)
  let status = status_bar.format_status(state)
  assert string.contains(status, "Black") == True
}

pub fn format_status_free_play_mode_test() {
  let state = app.new()
  let status = status_bar.format_status(state)
  assert string.contains(status, "[PLAY]") == True
  assert string.contains(status, "White") == True
  assert string.contains(status, "u:undo") == True
}

pub fn format_status_move_input_mode_test() {
  let state = AppState(..app.new(), mode: MoveInput, input_buffer: "Nf")
  let status = status_bar.format_status(state)
  assert string.contains(status, "> Nf") == True
}

pub fn format_status_move_input_empty_buffer_test() {
  let state = AppState(..app.new(), mode: MoveInput, input_buffer: "")
  let status = status_bar.format_status(state)
  assert string.contains(status, "> ") == True
}

// --- format_error ---

pub fn format_error_empty_test() {
  let state = app.new()
  assert status_bar.format_error(state) == ""
}

pub fn format_error_with_message_test() {
  let state = AppState(..app.new(), input_error: "Invalid: xyz")
  assert status_bar.format_error(state) == "Invalid: xyz"
}

// --- render produces commands ---

pub fn render_produces_positioned_commands_test() {
  let state = app.new()
  let commands = status_bar.render(state, 13)
  // Should contain at least a MoveTo and Print
  assert commands != []
}

// --- Browser mode status ---

pub fn format_status_browser_username_input_test() {
  let state = app.new()
  let #(state, _) = app.update(state, event.Char("b"))
  let status = status_bar.format_status(state)
  assert string.contains(status, "[BROWSE]") == True
  assert string.contains(status, "Enter username") == True
}

pub fn format_status_browser_archive_list_test() {
  let state = app.new()
  let #(state, _) = app.update(state, event.Char("b"))
  let #(state, _) = app.update(state, event.Char("h"))
  let #(state, _) = app.update(state, event.Enter)
  // Now in LoadingArchives
  let status = status_bar.format_status(state)
  assert string.contains(status, "Loading") == True
}

// --- Analysis status ---

pub fn format_status_replay_without_analysis_shows_r_hint_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let state = app.from_game(game.from_pgn(pgn_game))
  let status = status_bar.format_status(state)
  assert string.contains(status, "[REPLAY]") == True
  assert string.contains(status, " r ") == True
}

pub fn format_status_replay_with_analysis_shows_eval_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let state = app.from_game(game.from_pgn(pgn_game))
  let ga =
    GameAnalysis(
      evaluations: [Centipawns(0), Centipawns(35), Centipawns(20)],
      move_analyses: [],
    )
  let state = AppState(..state, analysis: option.Some(ga))
  let status = status_bar.format_status(state)
  assert string.contains(status, "[REPLAY]") == True
  assert string.contains(status, "0.00") == True
}

pub fn format_status_during_analysis_shows_progress_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let state = app.from_game(game.from_pgn(pgn_game))
  let state = AppState(..state, analysis_progress: option.Some(#(5, 41)))
  let status = status_bar.format_status(state)
  assert string.contains(status, "[ANALYZING]") == True
  assert string.contains(status, "5/41") == True
}
