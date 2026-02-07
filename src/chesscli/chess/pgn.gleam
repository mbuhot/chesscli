//// Parses PGN (Portable Game Notation) text into a structured game
//// representation by extracting tags and replaying moves from the
//// starting position.

import chesscli/chess/move.{type Move}
import chesscli/chess/position.{type Position}
import chesscli/chess/san
import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import gleam/string

/// A fully parsed PGN game with metadata tags, the sequence of moves,
/// and the resulting position after each move (including the start).
pub type PgnGame {
  PgnGame(
    tags: Dict(String, String),
    moves: List(Move),
    positions: List(Position),
  )
}

/// Errors that can occur during PGN parsing, covering malformed tags
/// and unrecognized or illegal SAN move tokens.
pub type PgnError {
  InvalidTag(String)
  InvalidMove(String)
  SanError(san.SanError)
}

/// Parse a PGN string into a PgnGame.
/// Extracts tags, then replays movetext from the starting position.
pub fn parse(pgn: String) -> Result(PgnGame, PgnError) {
  let #(tags, movetext) = split_sections(pgn)
  use tag_dict <- result.try(parse_tags(tags))
  let start_pos = position.initial()
  let tokens = tokenize_movetext(movetext)
  use #(moves, positions) <- result.try(
    replay_moves(tokens, start_pos, [], [start_pos]),
  )
  Ok(PgnGame(tags: tag_dict, moves: moves, positions: positions))
}

/// Split PGN into tag lines and movetext.
/// Tags are lines starting with '[', everything else is movetext.
fn split_sections(pgn: String) -> #(List(String), String) {
  let lines = string.split(pgn, "\n")
  split_sections_loop(lines, [], [])
}

fn split_sections_loop(
  lines: List(String),
  tags: List(String),
  movetext_lines: List(String),
) -> #(List(String), String) {
  case lines {
    [] -> #(list.reverse(tags), string.join(list.reverse(movetext_lines), " "))
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case string.starts_with(trimmed, "[") {
        True -> split_sections_loop(rest, [trimmed, ..tags], movetext_lines)
        False -> split_sections_loop(rest, tags, [trimmed, ..movetext_lines])
      }
    }
  }
}

/// Parse tag pairs like [Key "Value"].
fn parse_tags(
  tag_lines: List(String),
) -> Result(Dict(String, String), PgnError) {
  list.try_fold(tag_lines, dict.new(), fn(acc, line) {
    case parse_tag(line) {
      Ok(#(key, value)) -> Ok(dict.insert(acc, key, value))
      Error(e) -> Error(e)
    }
  })
}

fn parse_tag(line: String) -> Result(#(String, String), PgnError) {
  // Format: [Key "Value"]
  let trimmed = string.trim(line)
  case string.starts_with(trimmed, "[") && string.ends_with(trimmed, "]") {
    True -> {
      // Strip [ and ]
      let inner =
        trimmed
        |> string.drop_start(1)
        |> string.drop_end(1)
        |> string.trim

      // Find the space between key and "value"
      case string.split_once(inner, " ") {
        Ok(#(key, rest)) -> {
          let value =
            rest
            |> string.trim
            |> strip_quotes
          Ok(#(key, value))
        }
        Error(_) -> Error(InvalidTag(line))
      }
    }
    False -> Error(InvalidTag(line))
  }
}

fn strip_quotes(s: String) -> String {
  case string.starts_with(s, "\"") && string.ends_with(s, "\"") {
    True ->
      s
      |> string.drop_start(1)
      |> string.drop_end(1)
    False -> s
  }
}

/// Tokenize movetext: strip comments {}, NAGs $N, variations (),
/// move numbers, and result. Return only SAN move tokens.
fn tokenize_movetext(movetext: String) -> List(String) {
  movetext
  |> strip_comments
  |> strip_variations
  |> string.split(" ")
  |> list.filter(fn(token) {
    let trimmed = string.trim(token)
    trimmed != ""
    && !is_move_number(trimmed)
    && !is_result(trimmed)
    && !is_nag(trimmed)
  })
}

fn strip_comments(s: String) -> String {
  strip_between(s, "{", "}")
}

fn strip_variations(s: String) -> String {
  strip_between(s, "(", ")")
}

/// Remove all text between open and close delimiters (including nested).
fn strip_between(s: String, open: String, close: String) -> String {
  strip_between_loop(string.to_graphemes(s), open, close, 0, [])
}

fn strip_between_loop(
  chars: List(String),
  open: String,
  close: String,
  depth: Int,
  acc: List(String),
) -> String {
  case chars {
    [] -> list.reverse(acc) |> string.join("")
    [c, ..rest] -> {
      case c == open {
        True ->
          strip_between_loop(rest, open, close, depth + 1, acc)
        False ->
          case c == close && depth > 0 {
            True ->
              strip_between_loop(rest, open, close, depth - 1, acc)
            False ->
              case depth > 0 {
                True -> strip_between_loop(rest, open, close, depth, acc)
                False ->
                  strip_between_loop(rest, open, close, depth, [c, ..acc])
              }
          }
      }
    }
  }
}

fn is_move_number(s: String) -> Bool {
  // Matches "1.", "1...", "12.", etc.
  string.ends_with(s, ".") || string.ends_with(s, "...")
}

fn is_result(s: String) -> Bool {
  s == "1-0" || s == "0-1" || s == "1/2-1/2" || s == "*"
}

fn is_nag(s: String) -> Bool {
  string.starts_with(s, "$")
}

/// Replay SAN tokens from a starting position, building up
/// the move and position lists.
fn replay_moves(
  tokens: List(String),
  pos: Position,
  moves_acc: List(Move),
  positions_acc: List(Position),
) -> Result(#(List(Move), List(Position)), PgnError) {
  case tokens {
    [] -> Ok(#(list.reverse(moves_acc), list.reverse(positions_acc)))
    [token, ..rest] -> {
      case san.parse(token, pos) {
        Ok(m) -> {
          let new_pos = move.apply(pos, m)
          replay_moves(rest, new_pos, [m, ..moves_acc], [
            new_pos,
            ..positions_acc
          ])
        }
        Error(san_err) -> Error(SanError(san_err))
      }
    }
  }
}
