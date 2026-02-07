//// Pure UCI protocol types and formatting/parsing functions.
//// No IO — all functions are fully testable with simple inputs and outputs.

import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string

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

/// Negate a score, converting from one side's perspective to the other.
/// UCI reports scores from the side-to-move's perspective; use this to
/// normalize all evaluations to white's perspective.
pub fn negate_score(score: Score) -> Score {
  case score {
    Centipawns(cp) -> Centipawns(-cp)
    Mate(n) -> Mate(-n)
  }
}

/// Parse a UCI "info" line into a UciInfo record.
pub fn parse_info(line: String) -> Result(UciInfo, Nil) {
  let tokens = string.split(line, " ")
  case tokens {
    ["info", ..rest] -> parse_info_tokens(rest, 0, Error(Nil), [], 0)
    _ -> Error(Nil)
  }
}

/// Parse a UCI "bestmove" line, returning the best move and optional ponder move.
pub fn parse_bestmove(line: String) -> Result(#(String, Option(String)), Nil) {
  let tokens = string.split(line, " ")
  case tokens {
    ["bestmove", move, "ponder", ponder] ->
      Ok(#(move, option.Some(ponder)))
    ["bestmove", move] -> Ok(#(move, option.None))
    _ -> Error(Nil)
  }
}

fn parse_info_tokens(
  tokens: List(String),
  depth: Int,
  score: Result(Score, Nil),
  pv: List(String),
  nodes: Int,
) -> Result(UciInfo, Nil) {
  case tokens {
    [] ->
      case score {
        Ok(s) -> Ok(UciInfo(depth: depth, score: s, pv: list.reverse(pv), nodes: nodes))
        Error(_) -> Error(Nil)
      }
    ["depth", d, ..rest] -> {
      use d_int <- result.try(int.parse(d))
      parse_info_tokens(rest, d_int, score, pv, nodes)
    }
    ["score", "cp", val, ..rest] -> {
      use cp <- result.try(int.parse(val))
      parse_info_tokens(rest, depth, Ok(Centipawns(cp)), pv, nodes)
    }
    ["score", "mate", val, ..rest] -> {
      use m <- result.try(int.parse(val))
      parse_info_tokens(rest, depth, Ok(Mate(m)), pv, nodes)
    }
    ["nodes", n, ..rest] -> {
      use n_int <- result.try(int.parse(n))
      parse_info_tokens(rest, depth, score, pv, n_int)
    }
    ["pv", ..rest] -> {
      let pv_moves = list.filter(rest, fn(t) { t != "" })
      case score {
        Ok(s) -> Ok(UciInfo(depth: depth, score: s, pv: pv_moves, nodes: nodes))
        Error(_) -> Error(Nil)
      }
    }
    [_, ..rest] -> parse_info_tokens(rest, depth, score, pv, nodes)
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
