import chesscli/chess/color.{Black, White}
import chesscli/chess/fen
import chesscli/engine/analysis.{Blunder, Mistake}
import chesscli/puzzle/puzzle.{
  type Puzzle, Correct, Puzzle, Revealed,
}
import gleam/int
import gleam/list
import gleam/option

fn sample_puzzle() -> Puzzle {
  Puzzle(
    fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
    player_color: Black,
    solution_uci: "e7e5",
    played_uci: "a7a6",
    continuation: ["g1f3", "b8c6"],
    eval_before: "+0.30",
    eval_after: "-1.50",
    source_label: "vs opponent, 2024-01-15",
    classification: Mistake,
    white_name: "me",
    black_name: "opponent",
    solve_count: 0,
  )
}

fn sample_puzzle_2() -> Puzzle {
  Puzzle(
    ..sample_puzzle(),
    solution_uci: "d7d5",
    played_uci: "h7h6",
    classification: Blunder,
  )
}

// --- new_session ---

pub fn new_session_creates_at_index_zero_test() {
  let session = puzzle.new_session([sample_puzzle()])
  assert session.current_index == 0
  assert session.results == []
}

pub fn new_session_empty_puzzles_test() {
  let session = puzzle.new_session([])
  assert session.current_index == 0
  assert session.puzzles == []
}

// --- current_puzzle ---

pub fn current_puzzle_returns_first_test() {
  let p = sample_puzzle()
  let session = puzzle.new_session([p, sample_puzzle_2()])
  let assert option.Some(current) = puzzle.current_puzzle(session)
  assert current.solution_uci == "e7e5"
}

pub fn current_puzzle_empty_returns_none_test() {
  let session = puzzle.new_session([])
  assert puzzle.current_puzzle(session) == option.None
}

// --- check_move ---

pub fn check_move_correct_test() {
  let p = sample_puzzle()
  assert puzzle.check_move(p, "e7e5") == True
}

pub fn check_move_incorrect_test() {
  let p = sample_puzzle()
  assert puzzle.check_move(p, "d7d5") == False
}

pub fn check_move_case_insensitive_test() {
  let p = Puzzle(..sample_puzzle(), solution_uci: "e7e8q")
  assert puzzle.check_move(p, "e7e8Q") == True
}

// --- next_puzzle ---

pub fn next_puzzle_advances_test() {
  let session = puzzle.new_session([sample_puzzle(), sample_puzzle_2()])
  let assert Ok(session) = puzzle.next_puzzle(session)
  assert session.current_index == 1
}

pub fn next_puzzle_at_end_errors_test() {
  let session = puzzle.new_session([sample_puzzle()])
  let result = puzzle.next_puzzle(session)
  assert result == Error(Nil)
}

// --- prev_puzzle ---

pub fn prev_puzzle_goes_back_test() {
  let session = puzzle.new_session([sample_puzzle(), sample_puzzle_2()])
  let assert Ok(session) = puzzle.next_puzzle(session)
  let assert Ok(session) = puzzle.prev_puzzle(session)
  assert session.current_index == 0
}

pub fn prev_puzzle_at_start_errors_test() {
  let session = puzzle.new_session([sample_puzzle()])
  let result = puzzle.prev_puzzle(session)
  assert result == Error(Nil)
}

// --- record_result + stats ---

pub fn record_result_appends_test() {
  let session = puzzle.new_session([sample_puzzle(), sample_puzzle_2()])
  let session = puzzle.record_result(session, Correct)
  assert list.length(session.results) == 1
  let assert [#(0, Correct)] = session.results
}

pub fn stats_counts_correctly_test() {
  let session = puzzle.new_session([sample_puzzle(), sample_puzzle_2()])
  let session = puzzle.record_result(session, Correct)
  let assert Ok(session) = puzzle.next_puzzle(session)
  let session = puzzle.record_result(session, Revealed)
  let #(total, solved, revealed) = puzzle.stats(session)
  assert total == 2
  assert solved == 1
  assert revealed == 1
}

pub fn stats_empty_session_test() {
  let session = puzzle.new_session([sample_puzzle()])
  let #(total, solved, revealed) = puzzle.stats(session)
  assert total == 1
  assert solved == 0
  assert revealed == 0
}

// --- hint_piece ---

pub fn hint_piece_identifies_piece_test() {
  // Position after 1. e4: knight on g1
  let p =
    Puzzle(
      ..sample_puzzle(),
      fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
      player_color: White,
      solution_uci: "g1f3",
    )
  let assert Ok(pos) = fen.parse(p.fen)
  assert puzzle.hint_piece(p, pos.board) == "Move your knight"
}

pub fn hint_piece_pawn_test() {
  // Starting position, solution is e2e4
  let p =
    Puzzle(
      ..sample_puzzle(),
      fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
      player_color: White,
      solution_uci: "e2e4",
    )
  let assert Ok(pos) = fen.parse(p.fen)
  assert puzzle.hint_piece(p, pos.board) == "Move your pawn"
}

// --- hint_square ---

pub fn hint_square_shows_piece_and_destination_test() {
  let p =
    Puzzle(
      ..sample_puzzle(),
      fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
      player_color: White,
      solution_uci: "g1f3",
    )
  let assert Ok(pos) = fen.parse(p.fen)
  assert puzzle.hint_square(p, pos.board) == "Knight to f3"
}

// --- merge_puzzles ---

pub fn merge_puzzles_appends_new_test() {
  let p1 = sample_puzzle()
  let p2 = sample_puzzle_2()
  let result = puzzle.merge_puzzles([p1], [p2], 50)
  assert list.length(result) == 2
}

pub fn merge_puzzles_deduplicates_by_fen_and_solution_test() {
  let p1 = sample_puzzle()
  let p1_dup = Puzzle(..sample_puzzle(), played_uci: "different")
  let result = puzzle.merge_puzzles([p1], [p1_dup], 50)
  // Same fen + solution_uci → keeps the first one
  assert list.length(result) == 1
  let assert [kept] = result
  assert kept.played_uci == p1.played_uci
}

pub fn merge_puzzles_first_arg_wins_on_duplicate_test() {
  let updated = Puzzle(..sample_puzzle(), solve_count: 2)
  let stale = Puzzle(..sample_puzzle(), solve_count: 0)
  // Updated puzzles should come first so their solve_count is preserved
  let result = puzzle.merge_puzzles([updated], [stale], 50)
  let assert [kept] = result
  assert kept.solve_count == 2
}

pub fn merge_puzzles_caps_at_max_test() {
  let puzzles =
    list.range(1, 60)
    |> list.map(fn(i) {
      Puzzle(..sample_puzzle(), solution_uci: "e" <> int.to_string(i))
    })
  let result = puzzle.merge_puzzles([], puzzles, 50)
  assert list.length(result) == 50
}

pub fn merge_puzzles_keeps_existing_when_full_test() {
  let existing =
    list.range(1, 50)
    |> list.map(fn(i) {
      Puzzle(..sample_puzzle(), solution_uci: "a" <> int.to_string(i))
    })
  let new = [Puzzle(..sample_puzzle(), solution_uci: "new1")]
  let result = puzzle.merge_puzzles(existing, new, 50)
  // 51 unique puzzles, capped to 50 — new one is dropped
  assert list.length(result) == 50
  let assert [first, ..] = result
  assert first.solution_uci == "a1"
}

// --- restore_solve_counts ---

pub fn restore_solve_counts_copies_from_stored_test() {
  let fresh = [sample_puzzle(), Puzzle(..sample_puzzle(), solution_uci: "g1f3")]
  let stored = [
    Puzzle(..sample_puzzle(), solve_count: 2),
    Puzzle(..sample_puzzle(), solution_uci: "g1f3", solve_count: 1),
  ]
  let result = puzzle.restore_solve_counts(fresh, stored)
  let assert [p1, p2] = result
  assert p1.solve_count == 2
  assert p2.solve_count == 1
}

pub fn restore_solve_counts_leaves_new_at_zero_test() {
  let fresh = [Puzzle(..sample_puzzle(), solution_uci: "a2a4")]
  let stored = [Puzzle(..sample_puzzle(), solve_count: 2)]
  let result = puzzle.restore_solve_counts(fresh, stored)
  let assert [p1] = result
  assert p1.solve_count == 0
}

// --- update_solve_count ---

pub fn update_solve_count_increments_on_clean_solve_test() {
  let session = puzzle.new_session([sample_puzzle(), sample_puzzle_2()])
  let session = puzzle.update_solve_count(session, True)
  let assert option.Some(p) = puzzle.current_puzzle(session)
  assert p.solve_count == 1
}

pub fn update_solve_count_resets_on_hint_test() {
  let p = Puzzle(..sample_puzzle(), solve_count: 2)
  let session = puzzle.new_session([p])
  let session = puzzle.update_solve_count(session, False)
  let assert option.Some(updated) = puzzle.current_puzzle(session)
  assert updated.solve_count == 0
}

pub fn update_solve_count_only_affects_current_test() {
  let session = puzzle.new_session([sample_puzzle(), sample_puzzle_2()])
  let session = puzzle.update_solve_count(session, True)
  let assert Ok(session) = puzzle.next_puzzle(session)
  let assert option.Some(p2) = puzzle.current_puzzle(session)
  assert p2.solve_count == 0
}

// --- remove_mastered ---

pub fn remove_mastered_keeps_unmastered_test() {
  let puzzles = [sample_puzzle(), sample_puzzle_2()]
  let result = puzzle.remove_mastered(puzzles)
  assert list.length(result) == 2
}

pub fn remove_mastered_removes_at_three_test() {
  let mastered = Puzzle(..sample_puzzle(), solve_count: 3)
  let result = puzzle.remove_mastered([mastered, sample_puzzle_2()])
  assert list.length(result) == 1
}

pub fn remove_mastered_removes_above_three_test() {
  let mastered = Puzzle(..sample_puzzle(), solve_count: 5)
  let result = puzzle.remove_mastered([mastered])
  assert result == []
}
