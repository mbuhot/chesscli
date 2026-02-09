import chesscli/chess/board
import chesscli/chess/color
import chesscli/engine/analysis.{Blunder, Miss, Mistake}
import chesscli/puzzle/puzzle.{
  type Puzzle, Correct, HintPiece, HintSquare, Incorrect, Puzzle, Revealed,
  Solving,
}
import chesscli/tui/puzzle_view
import gleam/string

fn sample_puzzle() -> Puzzle {
  Puzzle(
    fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
    player_color: color.Black,
    solution_uci: "d7d5",
    played_uci: "e7e5",
    continuation: ["d7d5", "e4d5", "d8d5"],
    eval_before: "+0.2",
    eval_after: "+1.7",
    source_label: "Alice vs Bob, 2024.01.15",
    classification: Mistake,
    white_name: "Alice",
    black_name: "Bob",
    preceding_move_uci: "",
    solve_count: 0,
  )
}

fn sample_session() -> puzzle.TrainingSession {
  puzzle.new_session([sample_puzzle(), Puzzle(..sample_puzzle(), classification: Blunder)])
}

// --- format_header ---

pub fn format_header_first_puzzle_test() {
  let session = sample_session()
  assert puzzle_view.format_header(session) == "Puzzle 1/2"
}

pub fn format_header_second_puzzle_test() {
  let assert Ok(session) = puzzle.next_puzzle(sample_session())
  assert puzzle_view.format_header(session) == "Puzzle 2/2"
}

// --- format_badge ---

pub fn format_badge_mistake_test() {
  let p = sample_puzzle()
  assert puzzle_view.format_badge(p) == "Mistake"
}

pub fn format_badge_blunder_test() {
  let p = Puzzle(..sample_puzzle(), classification: Blunder)
  assert puzzle_view.format_badge(p) == "Blunder"
}

pub fn format_badge_miss_test() {
  let p = Puzzle(..sample_puzzle(), classification: Miss)
  assert puzzle_view.format_badge(p) == "Miss"
}

// --- format_instruction ---

pub fn format_instruction_black_test() {
  let p = sample_puzzle()
  assert puzzle_view.format_instruction(p) == "Find the best move for Black"
}

pub fn format_instruction_white_test() {
  let p = Puzzle(..sample_puzzle(), player_color: color.White)
  assert puzzle_view.format_instruction(p) == "Find the best move for White"
}

// --- format_solve_progress ---

pub fn format_solve_progress_zero_test() {
  let p = sample_puzzle()
  assert puzzle_view.format_solve_progress(p) == "Solved: 0/3"
}

pub fn format_solve_progress_one_test() {
  let p = Puzzle(..sample_puzzle(), solve_count: 1)
  assert puzzle_view.format_solve_progress(p) == "Solved: 1/3"
}

// --- format_phase_content ---

pub fn format_phase_solving_test() {
  let p = sample_puzzle()
  let content = puzzle_view.format_phase_content(Solving, p, board.initial(), "")
  assert content == []
}

pub fn format_phase_hint_piece_test() {
  let p = sample_puzzle()
  let content = puzzle_view.format_phase_content(HintPiece, p, board.initial(), "")
  let assert [_, hint] = content
  assert string.contains(hint, "pawn")
}

pub fn format_phase_hint_square_test() {
  let p = sample_puzzle()
  let content = puzzle_view.format_phase_content(HintSquare, p, board.initial(), "")
  let assert [_, hint] = content
  assert string.contains(hint, "d5")
}

pub fn format_phase_correct_test() {
  let p = sample_puzzle()
  let content = puzzle_view.format_phase_content(Correct, p, board.initial(), "Correct!")
  assert content == ["Correct!"]
}

pub fn format_phase_incorrect_test() {
  let p = sample_puzzle()
  let content =
    puzzle_view.format_phase_content(Incorrect, p, board.initial(), "Not the best move.")
  let assert [feedback, ..] = content
  assert feedback == "Not the best move."
}

pub fn format_phase_revealed_test() {
  let p = sample_puzzle()
  let content =
    puzzle_view.format_phase_content(
      Revealed, p, board.initial(), "Best: d7d5 (eval +0.2)")
  let assert [best, played, line] = content
  assert string.contains(best, "d7d5")
  assert string.contains(played, "e5")
  assert string.contains(played, "+1.7")
  assert string.contains(line, "d5")
}

// --- format_stats ---

pub fn format_stats_test() {
  let session = sample_session()
  let session = puzzle.record_result(session, Correct)
  assert puzzle_view.format_stats(session) == "1/2 solved, 0 revealed"
}

pub fn format_stats_with_revealed_test() {
  let session = sample_session()
  let session = puzzle.record_result(session, Revealed)
  assert puzzle_view.format_stats(session) == "0/2 solved, 1 revealed"
}
