import chesscli/chess/color.{Black, White}
import chesscli/engine/analysis.{
  Best, Blunder, Excellent, Good, Inaccuracy, Miss, Mistake,
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
  assert analysis.classify_move(0.05, "e2e4", "e2e4", 0.0) == Best
}

pub fn classify_move_excellent_test() {
  assert analysis.classify_move(0.05, "e2e4", "d2d4", 0.0) == Excellent
}

pub fn classify_move_good_test() {
  assert analysis.classify_move(0.2, "e2e4", "d2d4", 0.0) == Good
}

pub fn classify_move_inaccuracy_test() {
  assert analysis.classify_move(0.4, "e2e4", "d2d4", 0.0) == Inaccuracy
}

pub fn classify_move_mistake_test() {
  assert analysis.classify_move(1.5, "e2e4", "d2d4", 0.0) == Mistake
}

pub fn classify_move_blunder_test() {
  assert analysis.classify_move(2.5, "e2e4", "d2d4", 0.0) == Blunder
}

// --- Miss classification ---

pub fn classify_move_miss_requires_half_pawn_loss_test() {
  // Loss 0.5 with mover eval +2.0 → Miss (missed a real opportunity)
  assert analysis.classify_move(0.5, "e2e4", "d2d4", 2.0) == Miss
}

pub fn classify_move_small_loss_not_miss_test() {
  // Loss 0.24 with mover eval +5.17 → Good, not Miss (negligible difference)
  assert analysis.classify_move(0.24, "e2e4", "d2d4", 5.17) == Good
}

pub fn classify_move_not_miss_low_eval_test() {
  // Loss 0.7 but mover eval only +0.5 → Inaccuracy, not Miss
  assert analysis.classify_move(0.7, "e2e4", "d2d4", 0.5) == Inaccuracy
}

pub fn classify_move_miss_threshold_test() {
  // Exactly at loss+eval threshold: loss 0.5, mover_eval = 1.5 → Miss
  assert analysis.classify_move(0.5, "e2e4", "d2d4", 1.5) == Miss
  // Just below eval threshold: mover_eval = 1.49 → Inaccuracy
  assert analysis.classify_move(0.5, "e2e4", "d2d4", 1.49) == Inaccuracy
  // Just below loss threshold: loss 0.49 → Inaccuracy even with high eval
  assert analysis.classify_move(0.49, "e2e4", "d2d4", 5.0) == Inaccuracy
}

// --- classification_to_string ---

pub fn classification_to_string_test() {
  assert analysis.classification_to_string(Best) == "Best"
  assert analysis.classification_to_string(Excellent) == "Excellent"
  assert analysis.classification_to_string(Good) == "Good"
  assert analysis.classification_to_string(Miss) == "Miss"
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
  let pvs = [["e2e4", "e7e5"]]
  let colors = [White]
  let ga =
    analysis.build_game_analysis(evals, move_ucis, best_ucis, pvs, colors)
  assert ga.evaluations == evals
  assert list.length(ga.move_analyses) == 1
  let assert [ma] = ga.move_analyses
  assert ma.classification == Best
  assert ma.move_index == 0
  assert ma.best_move_pv == ["e2e4", "e7e5"]
}

pub fn build_game_analysis_two_moves_alternating_test() {
  // 1. e4 e5 — White plays best, Black plays best
  let evals = [Centipawns(0), Centipawns(20), Centipawns(10)]
  let move_ucis = ["e2e4", "e7e5"]
  let best_ucis = ["e2e4", "e7e5"]
  let pvs = [["e2e4", "e7e5"], ["e7e5", "g1f3"]]
  let colors = [White, Black]
  let ga =
    analysis.build_game_analysis(evals, move_ucis, best_ucis, pvs, colors)
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
  let pvs = [["e2e4", "e7e5"]]
  let colors = [White]
  let ga =
    analysis.build_game_analysis(evals, move_ucis, best_ucis, pvs, colors)
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
  let pvs = [[], []]
  let colors = [White, Black]
  let ga =
    analysis.build_game_analysis(evals, move_ucis, best_ucis, pvs, colors)
  #(ga, move_ucis, colors)
}

pub fn update_evaluation_first_position_test() {
  // Update position 0 — only move 0's eval_before changes
  let #(ga, move_ucis, colors) = two_move_game_analysis()
  let updated =
    analysis.update_evaluation(
      ga, 0, Centipawns(10), "d2d4", ["d2d4"], move_ucis, colors,
    )
  // Evaluation at index 0 changed
  let assert [first_eval, ..] = updated.evaluations
  assert first_eval == Centipawns(10)
  // Move 0 should be re-classified with new eval_before=10, eval_after=20
  let assert [ma0, ma1] = updated.move_analyses
  assert ma0.eval_before == Centipawns(10)
  assert ma0.best_move_uci == "d2d4"
  assert ma0.best_move_pv == ["d2d4"]
  // Move 1 should be unchanged
  assert ma1.eval_before == Centipawns(20)
}

pub fn update_evaluation_middle_position_test() {
  // Update position 1 (middle) — move 0's eval_after AND move 1's eval_before change
  let #(ga, move_ucis, colors) = two_move_game_analysis()
  let updated =
    analysis.update_evaluation(
      ga, 1, Centipawns(50), "d2d4", [], move_ucis, colors,
    )
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
    analysis.update_evaluation(
      ga, 2, Centipawns(-30), "d7d5", [], move_ucis, colors,
    )
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
  let pvs = [["e2e4"]]
  let colors = [White]
  let ga =
    analysis.build_game_analysis(evals, move_ucis, best_ucis, pvs, colors)
  let assert [ma] = ga.move_analyses
  assert ma.classification == Mistake
  // Now deepen position 1 to -200 — loss becomes 3.0 → Blunder
  let updated =
    analysis.update_evaluation(
      ga, 1, Centipawns(-200), "e2e4", [], move_ucis, colors,
    )
  let assert [ma_updated] = updated.move_analyses
  assert ma_updated.classification == Blunder
}

// --- should_skip_deep ---

fn all_best_game_analysis() -> analysis.GameAnalysis {
  // 3 positions, 2 moves — both Best
  let evals = [Centipawns(0), Centipawns(20), Centipawns(10)]
  let move_ucis = ["e2e4", "e7e5"]
  let best_ucis = ["e2e4", "e7e5"]
  let pvs = [[], []]
  let colors = [White, Black]
  analysis.build_game_analysis(evals, move_ucis, best_ucis, pvs, colors)
}

pub fn should_skip_deep_best_moves_test() {
  // Position 0: move_before doesn't exist, move_after is Best → skip
  let ga = all_best_game_analysis()
  assert analysis.should_skip_deep(0, ga) == True
}

pub fn should_skip_deep_middle_best_test() {
  // Position 1: move_before is Best, move_after is Best → skip
  let ga = all_best_game_analysis()
  assert analysis.should_skip_deep(1, ga) == True
}

pub fn should_skip_deep_last_best_test() {
  // Position 2 (last): move_before is Best, move_after doesn't exist → skip
  let ga = all_best_game_analysis()
  assert analysis.should_skip_deep(2, ga) == True
}

pub fn should_skip_deep_blunder_not_skipped_test() {
  // Move 0 is a Blunder — position 0 (eval_before of Blunder) should not skip
  let evals = [Centipawns(100), Centipawns(-200), Centipawns(50)]
  let move_ucis = ["g1h3", "e7e5"]
  let best_ucis = ["e2e4", "e7e5"]
  let pvs = [[], []]
  let colors = [White, Black]
  let ga = analysis.build_game_analysis(evals, move_ucis, best_ucis, pvs, colors)
  // Position 0 is eval_before of Blunder move → don't skip
  assert analysis.should_skip_deep(0, ga) == False
  // Position 1 is eval_after of Blunder AND eval_before of Best → don't skip
  assert analysis.should_skip_deep(1, ga) == False
}

pub fn should_skip_deep_overwhelming_eval_test() {
  // Both evals overwhelming (+600 cp), non-Best move but trivial
  let evals = [Centipawns(600), Centipawns(550), Centipawns(580)]
  let move_ucis = ["e2e4", "e7e5"]
  let best_ucis = ["d2d4", "d7d5"]
  let pvs = [[], []]
  let colors = [White, Black]
  let ga = analysis.build_game_analysis(evals, move_ucis, best_ucis, pvs, colors)
  // All positions have overwhelming eval → skip
  assert analysis.should_skip_deep(0, ga) == True
  assert analysis.should_skip_deep(1, ga) == True
  assert analysis.should_skip_deep(2, ga) == True
}

pub fn should_skip_deep_mate_scores_test() {
  // Mate scores are overwhelming
  let evals = [Mate(3), Mate(2), Mate(1)]
  let move_ucis = ["e2e4", "e7e5"]
  let best_ucis = ["d2d4", "d7d5"]
  let pvs = [[], []]
  let colors = [White, Black]
  let ga = analysis.build_game_analysis(evals, move_ucis, best_ucis, pvs, colors)
  assert analysis.should_skip_deep(0, ga) == True
  assert analysis.should_skip_deep(1, ga) == True
  assert analysis.should_skip_deep(2, ga) == True
}

pub fn should_skip_deep_mixed_test() {
  // Move 0: Blunder, Move 1: Best
  // Position 1 is eval_after of Blunder — should NOT skip
  let evals = [Centipawns(100), Centipawns(-200), Centipawns(-180)]
  let move_ucis = ["g1h3", "e7e5"]
  let best_ucis = ["e2e4", "e7e5"]
  let pvs = [[], []]
  let colors = [White, Black]
  let ga = analysis.build_game_analysis(evals, move_ucis, best_ucis, pvs, colors)
  // Position 2: move_before is Best, no move_after → skip
  assert analysis.should_skip_deep(2, ga) == True
  // Position 1: eval_after of Blunder → don't skip
  assert analysis.should_skip_deep(1, ga) == False
}

pub fn update_evaluation_new_best_move_test() {
  // Originally played == best (Best classification)
  // After update, best move changes → classification depends on loss
  let evals = [Centipawns(0), Centipawns(20)]
  let move_ucis = ["e2e4"]
  let best_ucis = ["e2e4"]
  let pvs = [["e2e4"]]
  let colors = [White]
  let ga =
    analysis.build_game_analysis(evals, move_ucis, best_ucis, pvs, colors)
  let assert [ma] = ga.move_analyses
  assert ma.classification == Best
  // Update position 0 with a different best move — now played != best
  // Loss is still small (0→20 = -0.2, clamped to 0) → Excellent
  let updated =
    analysis.update_evaluation(
      ga, 0, Centipawns(0), "d2d4", [], move_ucis, colors,
    )
  let assert [ma_updated] = updated.move_analyses
  assert ma_updated.best_move_uci == "d2d4"
  assert ma_updated.classification == Excellent
}
