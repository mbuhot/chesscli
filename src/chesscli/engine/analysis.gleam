//// Pure move classification and game analysis functions.
//// Compares engine evaluations to classify each move by quality.

import chesscli/chess/color.{type Color, Black, White}
import chesscli/engine/uci.{type Score, Centipawns, Mate}
import gleam/float
import gleam/int

/// Quality classification for a single move.
pub type MoveClassification {
  Best
  Excellent
  Good
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

/// Classify a move based on eval loss and whether the played move matches the engine's best.
pub fn classify_move(
  loss: Float,
  played_uci: String,
  best_uci: String,
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
              case loss <. 1.0 {
                True -> Inaccuracy
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

/// Human-readable label for a classification.
pub fn classification_to_string(class: MoveClassification) -> String {
  case class {
    Best -> "Best"
    Excellent -> "Excellent"
    Good -> "Good"
    Inaccuracy -> "Inaccuracy"
    Mistake -> "Mistake"
    Blunder -> "Blunder"
  }
}
