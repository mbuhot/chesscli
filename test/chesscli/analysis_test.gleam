import chesscli/chess/color.{Black, White}
import chesscli/engine/analysis.{
  Best, Blunder, Excellent, Good, Inaccuracy, Mistake,
}
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
