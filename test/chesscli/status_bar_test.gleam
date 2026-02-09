import chesscli/chess/game
import chesscli/chess/pgn
import chesscli/engine/analysis.{GameAnalysis, Mistake}
import chesscli/engine/uci.{Centipawns}
import chesscli/puzzle/puzzle.{Puzzle}
import chesscli/tui/app.{AppState}
import chesscli/tui/status_bar
import etch/event
import gleam/option
import gleam/string

// --- format_status ---

pub fn format_status_replay_mode_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let state = app.from_game(game.from_pgn(pgn_game))
  let status = status_bar.format_status(state)
  assert status == ""
}

pub fn format_status_replay_after_move_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let g = game.from_pgn(pgn_game)
  let assert Ok(g) = game.forward(g)
  let state = AppState(..app.from_game(g), game: g)
  let status = status_bar.format_status(state)
  assert status == ""
}

pub fn format_status_free_play_mode_test() {
  let state = app.new()
  let status = status_bar.format_status(state)
  assert status == ""
}

pub fn format_status_with_input_buffer_test() {
  let state = AppState(..app.new(), input_buffer: "Nf")
  let status = status_bar.format_status(state)
  assert string.contains(status, "> Nf") == True
}

pub fn format_status_empty_buffer_shows_empty_test() {
  let state = app.new()
  let status = status_bar.format_status(state)
  assert status == ""
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
  // Open menu, then press 'b'
  let #(state, _) = app.update(state, event.Esc)
  let #(state, _) = app.update(state, event.Char("b"))
  let status = status_bar.format_status(state)
  assert string.contains(status, "[BROWSE]") == True
  assert string.contains(status, "Enter username") == True
}

pub fn format_status_browser_archive_list_test() {
  let state = app.new()
  let #(state, _) = app.update(state, event.Esc)
  let #(state, _) = app.update(state, event.Char("b"))
  let #(state, _) = app.update(state, event.Char("h"))
  let #(state, _) = app.update(state, event.Enter)
  // Now in LoadingArchives
  let status = status_bar.format_status(state)
  assert string.contains(status, "Loading") == True
}

// --- Analysis status ---

pub fn format_status_replay_without_analysis_empty_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let state = app.from_game(game.from_pgn(pgn_game))
  let status = status_bar.format_status(state)
  assert status == ""
}

pub fn format_status_replay_with_analysis_empty_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let state = app.from_game(game.from_pgn(pgn_game))
  let ga =
    GameAnalysis(
      evaluations: [Centipawns(0), Centipawns(35), Centipawns(20)],
      move_analyses: [],
    )
  let state = AppState(..state, analysis: option.Some(ga))
  let status = status_bar.format_status(state)
  assert status == ""
}

pub fn format_status_during_analysis_shows_progress_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let state = app.from_game(game.from_pgn(pgn_game))
  let state = AppState(..state, analysis_progress: option.Some(#(5, 41)))
  let status = status_bar.format_status(state)
  assert string.contains(status, "[ANALYZING]") == True
  assert string.contains(status, "5/41") == True
}

// --- Puzzle mode status ---

fn puzzle_status_state() -> app.AppState {
  let p =
    Puzzle(
      fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
      player_color: game.new().positions |> fn(positions) {
        let assert [pos, ..] = positions
        pos.active_color
      },
      solution_uci: "d7d5",
      played_uci: "e7e5",
      continuation: [],
      eval_before: "+0.2",
      eval_after: "+1.7",
      source_label: "test",
      classification: Mistake,
      white_name: "White",
      black_name: "Black",
      preceding_move_uci: "",
      solve_count: 0,
    )
  let session = puzzle.new_session([p])
  app.enter_puzzle_mode(app.from_game(game.new()), session)
}

pub fn format_status_puzzle_mode_empty_test() {
  let state = puzzle_status_state()
  let status = status_bar.format_status(state)
  assert status == ""
}

pub fn format_status_puzzle_no_session_empty_test() {
  let state = AppState(..app.new(), mode: app.PuzzleTraining)
  let status = status_bar.format_status(state)
  assert status == ""
}
