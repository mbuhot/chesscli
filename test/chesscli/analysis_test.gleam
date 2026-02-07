import chesscli/chess/color.{Black, White}
import chesscli/engine/analysis.{
  Best, Blunder, Excellent, GameAnalysis, Good, Inaccuracy, Mistake,
  MoveAnalysis,
}
import gleam/list
import chesscli/engine/uci.{Centipawns, Mate}
import gleam/float

fn approx_eq(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <. 0.001
}

// --- score_to_pawns ---

pub fn score_to_pawns_zero_test() {
  assert approx_eq(analysis.score_to_pawns(Centipawns(0)), 0.0)
}

pub fn score_to_pawns_positive_test() {
  assert approx_eq(analysis.score_to_pawns(Centipawns(150)), 1.5)
}

pub fn score_to_pawns_negative_test() {
  assert approx_eq(analysis.score_to_pawns(Centipawns(-200)), -2.0)
}

pub fn score_to_pawns_mate_positive_test() {
  assert analysis.score_to_pawns(Mate(3)) >. 99.0
}

pub fn score_to_pawns_mate_negative_test() {
  assert analysis.score_to_pawns(Mate(-2)) <. -99.0
}

// --- eval_loss ---

pub fn eval_loss_white_good_move_test() {
  // White's eval improves from +0.5 to +1.0 — no loss
  let loss = analysis.eval_loss(Centipawns(50), Centipawns(100), White)
  assert approx_eq(loss, 0.0)
}

pub fn eval_loss_white_bad_move_test() {
  // White's eval drops from +1.0 to -0.5 — 1.5 pawn loss
  let loss = analysis.eval_loss(Centipawns(100), Centipawns(-50), White)
  assert approx_eq(loss, 1.5)
}

pub fn eval_loss_black_good_move_test() {
  // Black's perspective: eval goes from +0.5 to -0.5 (good for black) — no loss
  let loss = analysis.eval_loss(Centipawns(50), Centipawns(-50), Black)
  assert approx_eq(loss, 0.0)
}

pub fn eval_loss_black_bad_move_test() {
  // Black's perspective: eval goes from -1.0 to +1.0 (bad for black) — 2.0 loss
  let loss = analysis.eval_loss(Centipawns(-100), Centipawns(100), Black)
  assert approx_eq(loss, 2.0)
}

// --- classify_move ---

pub fn classify_move_best_test() {
  assert analysis.classify_move(0.05, "e2e4", "e2e4") == Best
}

pub fn classify_move_excellent_test() {
  assert analysis.classify_move(0.05, "e2e4", "d2d4") == Excellent
}

pub fn classify_move_good_test() {
  assert analysis.classify_move(0.2, "e2e4", "d2d4") == Good
}

pub fn classify_move_inaccuracy_test() {
  assert analysis.classify_move(0.5, "e2e4", "d2d4") == Inaccuracy
}

pub fn classify_move_mistake_test() {
  assert analysis.classify_move(1.5, "e2e4", "d2d4") == Mistake
}

pub fn classify_move_blunder_test() {
  assert analysis.classify_move(2.5, "e2e4", "d2d4") == Blunder
}

// --- classification_to_string ---

pub fn classification_to_string_test() {
  assert analysis.classification_to_string(Best) == "Best"
  assert analysis.classification_to_string(Excellent) == "Excellent"
  assert analysis.classification_to_string(Good) == "Good"
  assert analysis.classification_to_string(Inaccuracy) == "Inaccuracy"
  assert analysis.classification_to_string(Mistake) == "Mistake"
  assert analysis.classification_to_string(Blunder) == "Blunder"
}

// --- build_game_analysis ---

pub fn build_game_analysis_simple_test() {
  // One move game: White plays e2e4, best was e2e4
  // Evals: [0, +20] — two positions, one move
  let evals = [Centipawns(0), Centipawns(20)]
  let move_ucis = ["e2e4"]
  let best_ucis = ["e2e4"]
  let colors = [White]
  let ga = analysis.build_game_analysis(evals, move_ucis, best_ucis, colors)
  assert ga.evaluations == evals
  assert list.length(ga.move_analyses) == 1
  let assert [ma] = ga.move_analyses
  assert ma.classification == Best
  assert ma.move_index == 0
}

pub fn build_game_analysis_two_moves_alternating_test() {
  // 1. e4 e5 — White plays best, Black plays best
  let evals = [Centipawns(0), Centipawns(20), Centipawns(10)]
  let move_ucis = ["e2e4", "e7e5"]
  let best_ucis = ["e2e4", "e7e5"]
  let colors = [White, Black]
  let ga = analysis.build_game_analysis(evals, move_ucis, best_ucis, colors)
  assert list.length(ga.move_analyses) == 2
  let assert [ma0, ma1] = ga.move_analyses
  assert ma0.classification == Best
  assert ma1.classification == Best
}

pub fn build_game_analysis_detects_blunder_test() {
  // White has +1.0, plays bad move, eval becomes -2.0 (3.0 pawn loss = blunder)
  let evals = [Centipawns(100), Centipawns(-200)]
  let move_ucis = ["g1h3"]
  let best_ucis = ["e2e4"]
  let colors = [White]
  let ga = analysis.build_game_analysis(evals, move_ucis, best_ucis, colors)
  let assert [ma] = ga.move_analyses
  assert ma.classification == Blunder
  assert ma.best_move_uci == "e2e4"
}

// --- update_evaluation ---

fn two_move_game_analysis() -> #(
  analysis.GameAnalysis,
  List(String),
  List(color.Color),
) {
  // 1. e4 e5 — evals [0, +20, +10], both Best moves
  let evals = [Centipawns(0), Centipawns(20), Centipawns(10)]
  let move_ucis = ["e2e4", "e7e5"]
  let best_ucis = ["e2e4", "e7e5"]
  let colors = [White, Black]
  let ga = analysis.build_game_analysis(evals, move_ucis, best_ucis, colors)
  #(ga, move_ucis, colors)
}

pub fn update_evaluation_first_position_test() {
  // Update position 0 — only move 0's eval_before changes
  let #(ga, move_ucis, colors) = two_move_game_analysis()
  let updated =
    analysis.update_evaluation(ga, 0, Centipawns(10), "d2d4", move_ucis, colors)
  // Evaluation at index 0 changed
  let assert [first_eval, ..] = updated.evaluations
  assert first_eval == Centipawns(10)
  // Move 0 should be re-classified with new eval_before=10, eval_after=20
  let assert [ma0, ma1] = updated.move_analyses
  assert ma0.eval_before == Centipawns(10)
  assert ma0.best_move_uci == "d2d4"
  // Move 1 should be unchanged
  assert ma1.eval_before == Centipawns(20)
}

pub fn update_evaluation_middle_position_test() {
  // Update position 1 (middle) — move 0's eval_after AND move 1's eval_before change
  let #(ga, move_ucis, colors) = two_move_game_analysis()
  let updated =
    analysis.update_evaluation(ga, 1, Centipawns(50), "d2d4", move_ucis, colors)
  // Move 0's eval_after changed
  let assert [ma0, ma1] = updated.move_analyses
  assert ma0.eval_after == Centipawns(50)
  // Move 1's eval_before changed
  assert ma1.eval_before == Centipawns(50)
}

pub fn update_evaluation_last_position_test() {
  // Update last position (index 2) — only move 1's eval_after changes
  let #(ga, move_ucis, colors) = two_move_game_analysis()
  let updated =
    analysis.update_evaluation(ga, 2, Centipawns(-30), "d7d5", move_ucis, colors)
  let assert [ma0, ma1] = updated.move_analyses
  // Move 0 unchanged
  assert ma0.eval_after == Centipawns(20)
  // Move 1's eval_after changed
  assert ma1.eval_after == Centipawns(-30)
}

pub fn update_evaluation_changes_classification_test() {
  // White has +1.0, plays move, eval after is -0.5 (originally Good)
  // Update eval_after to -2.0 → 3.0 pawn loss → Blunder
  let evals = [Centipawns(100), Centipawns(-50)]
  let move_ucis = ["g1h3"]
  let best_ucis = ["e2e4"]
  let colors = [White]
  let ga = analysis.build_game_analysis(evals, move_ucis, best_ucis, colors)
  let assert [ma] = ga.move_analyses
  assert ma.classification == Mistake
  // Now deepen position 1 to -200 — loss becomes 3.0 → Blunder
  let updated =
    analysis.update_evaluation(ga, 1, Centipawns(-200), "e2e4", move_ucis, colors)
  let assert [ma_updated] = updated.move_analyses
  assert ma_updated.classification == Blunder
}

pub fn update_evaluation_new_best_move_test() {
  // Originally played == best (Best classification)
  // After update, best move changes → classification depends on loss
  let evals = [Centipawns(0), Centipawns(20)]
  let move_ucis = ["e2e4"]
  let best_ucis = ["e2e4"]
  let colors = [White]
  let ga = analysis.build_game_analysis(evals, move_ucis, best_ucis, colors)
  let assert [ma] = ga.move_analyses
  assert ma.classification == Best
  // Update position 0 with a different best move — now played != best
  // Loss is still small (0→20 = -0.2, clamped to 0) → Excellent
  let updated =
    analysis.update_evaluation(ga, 0, Centipawns(0), "d2d4", move_ucis, colors)
  let assert [ma_updated] = updated.move_analyses
  assert ma_updated.best_move_uci == "d2d4"
  assert ma_updated.classification == Excellent
}
