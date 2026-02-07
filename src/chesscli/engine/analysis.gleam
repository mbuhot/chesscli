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

/// Build a complete game analysis from per-position evaluations and best moves.
/// Takes N+1 evaluations (one per position), N move UCIs, N best-move UCIs,
/// and a list of active colors for each move.
pub fn build_game_analysis(
  evaluations: List(Score),
  move_ucis: List(String),
  best_move_ucis: List(String),
  active_colors: List(Color),
) -> GameAnalysis {
  let eval_pairs = list.window_by_2(evaluations)
  let zipped =
    list.zip(eval_pairs, list.zip(move_ucis, list.zip(best_move_ucis, active_colors)))
  let move_analyses =
    list.index_map(zipped, fn(entry, idx) {
      let #(#(eval_before, eval_after), #(played, #(best, color))) = entry
      let loss = eval_loss(eval_before, eval_after, color)
      let classification = classify_move(loss, played, best)
      MoveAnalysis(
        move_index: idx,
        eval_before: eval_before,
        eval_after: eval_after,
        best_move_uci: best,
        classification: classification,
      )
    })
  GameAnalysis(evaluations: evaluations, move_analyses: move_analyses)
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
