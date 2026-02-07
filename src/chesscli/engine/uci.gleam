//// Pure UCI protocol types and formatting/parsing functions.
//// No IO — all functions are fully testable with simple inputs and outputs.

import gleam/int

/// Engine evaluation score, either in centipawns or moves-to-mate.
pub type Score {
  Centipawns(Int)
  Mate(Int)
}

/// Parsed info line from UCI engine output.
pub type UciInfo {
  UciInfo(depth: Int, score: Score, pv: List(String), nodes: Int)
}

/// Format a FEN position as a UCI "position" command.
pub fn format_position(fen: String) -> String {
  "position fen " <> fen
}

/// Format a UCI "go depth" command.
pub fn format_go(depth: Int) -> String {
  "go depth " <> int.to_string(depth)
}

/// Format a score for human-readable display (e.g. "+0.35", "-1.50", "M3", "-M2").
pub fn format_score(score: Score) -> String {
  case score {
    Centipawns(cp) -> format_centipawns(cp)
    Mate(n) if n > 0 -> "M" <> int.to_string(n)
    Mate(n) -> "-M" <> int.to_string(int.absolute_value(n))
  }
}

fn format_centipawns(cp: Int) -> String {
  let abs = int.absolute_value(cp)
  let whole = abs / 100
  let frac = abs % 100
  let frac_str = case frac < 10 {
    True -> "0" <> int.to_string(frac)
    False -> int.to_string(frac)
  }
  let num = int.to_string(whole) <> "." <> frac_str
  case cp > 0 {
    True -> "+" <> num
    False ->
      case cp < 0 {
        True -> "-" <> num
        False -> num
      }
  }
}
