//// Pure move classification and game analysis functions.
//// Compares engine evaluations to classify each move by quality.

import chesscli/chess/color.{type Color, Black, White}
import chesscli/engine/uci.{type Score, Centipawns, Mate}
import gleam/float
import gleam/int
import gleam/list

/// Quality classification for a single move.
pub type MoveClassification {
  Best
  Excellent
  Good
  Miss
  Inaccuracy
  Mistake
  Blunder
}

/// Analysis of a single move: what the eval was before/after, what the engine
/// preferred, and how the played move compares.
pub type MoveAnalysis {
  MoveAnalysis(
    move_index: Int,
    eval_before: Score,
    eval_after: Score,
    best_move_uci: String,
    best_move_pv: List(String),
    classification: MoveClassification,
  )
}

/// Complete analysis of a game: per-position evaluations and per-move classifications.
pub type GameAnalysis {
  GameAnalysis(
    evaluations: List(Score),
    move_analyses: List(MoveAnalysis),
  )
}

/// Convert a score to a floating-point pawn value for loss calculations.
pub fn score_to_pawns(score: Score) -> Float {
  case score {
    Centipawns(cp) -> int.to_float(cp) /. 100.0
    Mate(n) if n > 0 -> 100.0
    Mate(_) -> -100.0
  }
}

/// Compute the evaluation loss from the mover's perspective.
/// A positive result means the player lost eval; zero means no loss (or improvement).
pub fn eval_loss(before: Score, after: Score, active_color: Color) -> Float {
  let before_pawns = score_to_pawns(before)
  let after_pawns = score_to_pawns(after)
  let swing = case active_color {
    White -> before_pawns -. after_pawns
    Black -> after_pawns -. before_pawns
  }
  float.max(swing, 0.0)
}

/// Classify a move based on eval loss, whether the played move matches the
/// engine's best, and the mover's eval before the move (for Miss detection).
/// A Miss requires loss >= 0.5 in a winning position (mover_eval >= 1.5) —
/// small differences (< 0.5) are normal Good/Inaccuracy moves, not missed tactics.
pub fn classify_move(
  loss: Float,
  played_uci: String,
  best_uci: String,
  mover_eval_before: Float,
) -> MoveClassification {
  case played_uci == best_uci {
    True -> Best
    False ->
      case loss <. 0.1 {
        True -> Excellent
        False ->
          case loss <. 0.3 {
            True -> Good
            False ->
              case loss <. 0.5 {
                True -> Inaccuracy
                False ->
                  case loss <. 1.0 {
                    True ->
                      case mover_eval_before >=. 1.5 {
                        True -> Miss
                        False -> Inaccuracy
                      }
                    False ->
                      case loss <. 2.0 {
                        True -> Mistake
                        False -> Blunder
                      }
                  }
              }
          }
      }
  }
}

/// Build a complete game analysis from per-position evaluations and best moves.
/// Takes N+1 evaluations (one per position), N move UCIs, N best-move UCIs,
/// N PV lists, and a list of active colors for each move.
pub fn build_game_analysis(
  evaluations: List(Score),
  move_ucis: List(String),
  best_move_ucis: List(String),
  best_move_pvs: List(List(String)),
  active_colors: List(Color),
) -> GameAnalysis {
  let eval_pairs = list.window_by_2(evaluations)
  let zipped =
    list.zip(
      eval_pairs,
      list.zip(move_ucis, list.zip(best_move_ucis, list.zip(best_move_pvs, active_colors))),
    )
  let move_analyses =
    list.index_map(zipped, fn(entry, idx) {
      let #(#(eval_before, eval_after), #(played, #(best, #(pv, color)))) =
        entry
      let loss = eval_loss(eval_before, eval_after, color)
      let mover_eval = mover_eval_before(eval_before, color)
      let classification = classify_move(loss, played, best, mover_eval)
      MoveAnalysis(
        move_index: idx,
        eval_before: eval_before,
        eval_after: eval_after,
        best_move_uci: best,
        best_move_pv: pv,
        classification: classification,
      )
    })
  GameAnalysis(evaluations: evaluations, move_analyses: move_analyses)
}

/// Compute the eval from the mover's perspective (positive = good for mover).
pub fn mover_eval_before(eval_before: Score, color: Color) -> Float {
  let pawns = score_to_pawns(eval_before)
  case color {
    White -> pawns
    Black -> float.negate(pawns)
  }
}

/// Update a single position's evaluation in an existing GameAnalysis.
/// Replaces the score at position_index in evaluations, updates the best_move_uci
/// and PV, and re-classifies the affected move(s): move at index-1 (eval_after
/// changes) and move at index (eval_before changes).
pub fn update_evaluation(
  ga: GameAnalysis,
  position_index: Int,
  new_score: Score,
  new_best_uci: String,
  new_best_pv: List(String),
  move_ucis: List(String),
  active_colors: List(Color),
) -> GameAnalysis {
  let new_evals = list_replace(ga.evaluations, position_index, new_score)
  let new_move_analyses =
    list.index_map(ga.move_analyses, fn(ma, idx) {
      let affects_as_before = idx == position_index
      let affects_as_after = idx == position_index - 1
      case affects_as_before, affects_as_after {
        True, _ -> {
          let eval_before = new_score
          let assert Ok(played) = list_at(move_ucis, idx)
          let assert Ok(color) = list_at(active_colors, idx)
          let loss = eval_loss(eval_before, ma.eval_after, color)
          let me = mover_eval_before(eval_before, color)
          let classification = classify_move(loss, played, new_best_uci, me)
          MoveAnalysis(
            ..ma,
            eval_before: eval_before,
            best_move_uci: new_best_uci,
            best_move_pv: new_best_pv,
            classification: classification,
          )
        }
        _, True -> {
          let eval_after = new_score
          let assert Ok(played) = list_at(move_ucis, idx)
          let assert Ok(color) = list_at(active_colors, idx)
          let loss = eval_loss(ma.eval_before, eval_after, color)
          let me = mover_eval_before(ma.eval_before, color)
          let classification =
            classify_move(loss, played, ma.best_move_uci, me)
          MoveAnalysis(
            ..ma,
            eval_after: eval_after,
            classification: classification,
          )
        }
        _, _ -> ma
      }
    })
  GameAnalysis(evaluations: new_evals, move_analyses: new_move_analyses)
}

fn list_replace(lst: List(a), index: Int, value: a) -> List(a) {
  list.index_map(lst, fn(item, i) {
    case i == index {
      True -> value
      False -> item
    }
  })
}

fn list_at(lst: List(a), index: Int) -> Result(a, Nil) {
  case lst, index {
    [], _ -> Error(Nil)
    [head, ..], 0 -> Ok(head)
    [_, ..tail], n if n > 0 -> list_at(tail, n - 1)
    _, _ -> Error(Nil)
  }
}

/// Whether a position can be skipped during the deep analysis pass.
/// A position is skippable when both adjacent moves are "settled" — either
/// classified as Best (engine's top choice) or with overwhelming eval on both sides.
pub fn should_skip_deep(position_index: Int, ga: GameAnalysis) -> Bool {
  let move_before_settled = case list_at(ga.move_analyses, position_index - 1) {
    Ok(ma) -> is_settled(ma)
    Error(_) -> True
  }
  let move_after_settled = case list_at(ga.move_analyses, position_index) {
    Ok(ma) -> is_settled(ma)
    Error(_) -> True
  }
  move_before_settled && move_after_settled
}

/// A move is settled if classified Best, or if both evals are overwhelming.
fn is_settled(ma: MoveAnalysis) -> Bool {
  case ma.classification {
    Best -> True
    _ -> is_overwhelming_eval(ma.eval_before) && is_overwhelming_eval(ma.eval_after)
  }
}

/// An eval is overwhelming if |cp| >= 500 or it's a Mate score.
fn is_overwhelming_eval(score: Score) -> Bool {
  case score {
    Centipawns(cp) -> int.absolute_value(cp) >= 500
    Mate(_) -> True
  }
}

/// Human-readable label for a classification.
pub fn classification_to_string(class: MoveClassification) -> String {
  case class {
    Best -> "Best"
    Excellent -> "Excellent"
    Good -> "Good"
    Miss -> "Miss"
    Inaccuracy -> "Inaccuracy"
    Mistake -> "Mistake"
    Blunder -> "Blunder"
  }
}
