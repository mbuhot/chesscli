//// Standard Algebraic Notation (SAN) parsing and formatting.
//// Converts between human-readable move strings (e.g. "Nf3", "O-O", "exd5")
//// and internal Move values, handling disambiguation and check/mate suffixes.

import chesscli/chess/move.{type Move}
import chesscli/chess/move_gen
import chesscli/chess/piece.{type Piece, Bishop, King, Knight, Pawn, Queen, Rook}
import chesscli/chess/position.{type Position}
import chesscli/chess/square.{type Square}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// Errors that can occur when parsing a SAN string against a position.
pub type SanError {
  /// The notation is syntactically invalid.
  InvalidSan(String)
  /// Multiple legal moves match the notation (needs disambiguation).
  AmbiguousMove(String)
  /// No legal move matches the notation in the current position.
  NoMatchingMove(String)
}

/// Parse a SAN string (e.g. "e4", "Nf3", "O-O", "exd5", "e8=Q") into a Move,
/// given the current position for disambiguation and legal move validation.
pub fn parse(san: String, pos: Position) -> Result(Move, SanError) {
  // Strip check/mate suffixes
  let clean = strip_suffixes(san)

  case clean {
    "O-O" -> parse_castling(pos, kingside: True)
    "O-O-O" -> parse_castling(pos, kingside: False)
    _ -> parse_standard_move(clean, pos)
  }
}

/// Format a move as SAN given the position before the move.
pub fn to_string(m: Move, pos: Position) -> String {
  case m.is_castling {
    True ->
      case square.file_to_int(m.to.file) > square.file_to_int(m.from.file) {
        True -> "O-O"
        False -> "O-O-O"
      }
    False -> format_standard_move(m, pos)
  }
  |> add_check_suffix(m, pos)
}

fn strip_suffixes(san: String) -> String {
  san
  |> string.replace("+", "")
  |> string.replace("#", "")
}

fn parse_castling(
  pos: Position,
  kingside kingside: Bool,
) -> Result(Move, SanError) {
  let legal = move_gen.legal_moves(pos)
  let target_file = case kingside {
    True -> square.G
    False -> square.C
  }
  let matching =
    list.filter(legal, fn(m) {
      m.is_castling && square.file_to_int(m.to.file) == square.file_to_int(target_file)
    })
  case matching {
    [m] -> Ok(m)
    [] ->
      Error(NoMatchingMove(case kingside {
        True -> "O-O"
        False -> "O-O-O"
      }))
    _ ->
      Error(AmbiguousMove(case kingside {
        True -> "O-O"
        False -> "O-O-O"
      }))
  }
}

fn parse_standard_move(
  san: String,
  pos: Position,
) -> Result(Move, SanError) {
  let chars = string.to_graphemes(san)
  case chars {
    [] -> Error(InvalidSan(san))
    [first, ..] -> {
      case is_uppercase(first) {
        // Piece move: Nf3, Bxe5, Raxd1, R1d3, Qh4e1
        True -> parse_piece_move(san, chars, pos)
        // Pawn move: e4, exd5, e8=Q
        False -> parse_pawn_move(san, chars, pos)
      }
    }
  }
}

fn parse_piece_move(
  san: String,
  chars: List(String),
  pos: Position,
) -> Result(Move, SanError) {
  use piece <- result.try(piece_from_letter(san, chars))
  let rest = case chars {
    [_, ..r] -> r
    _ -> []
  }

  // Remove 'x' capture indicator
  let rest = list.filter(rest, fn(c) { c != "x" })

  // The last 2 chars are always the destination square
  let rest_len = list.length(rest)
  case rest_len >= 2 {
    True -> {
      let dest_chars = list.drop(rest, rest_len - 2)
      let disambig_chars = list.take(rest, rest_len - 2)
      use dest <- result.try(parse_square_chars(san, dest_chars))
      let legal = move_gen.legal_moves(pos)
      let candidates =
        list.filter(legal, fn(m) {
          case board_piece_at(pos, m.from) {
            Some(p) -> p == piece && m.to == dest && !m.is_castling
            None -> False
          }
        })
      filter_disambiguation(san, candidates, disambig_chars)
    }
    False -> Error(InvalidSan(san))
  }
}

fn parse_pawn_move(
  san: String,
  chars: List(String),
  pos: Position,
) -> Result(Move, SanError) {
  // Check for promotion: e8=Q
  let #(chars, promotion) = extract_promotion(chars)

  // Remove 'x' capture indicator
  let has_capture = list.any(chars, fn(c) { c == "x" })
  let chars = list.filter(chars, fn(c) { c != "x" })

  let chars_len = list.length(chars)
  case chars_len {
    // Simple push: "e4"
    2 -> {
      use dest <- result.try(parse_square_chars(san, chars))
      find_pawn_move(san, pos, dest, None, promotion)
    }
    // Capture with file prefix: "ed5" (3 chars after removing x)
    3 -> {
      let assert [file_char, ..dest_chars] = chars
      use from_file <- result.try(parse_file_char(san, file_char))
      use dest <- result.try(parse_square_chars(san, dest_chars))
      find_pawn_move(san, pos, dest, Some(from_file), promotion)
    }
    _ ->
      case has_capture && chars_len == 2 {
        // This case shouldn't occur given the flow above; safeguard
        True -> Error(InvalidSan(san))
        False -> Error(InvalidSan(san))
      }
  }
}

fn find_pawn_move(
  san: String,
  pos: Position,
  dest: Square,
  from_file: Option(square.File),
  promotion: Option(Piece),
) -> Result(Move, SanError) {
  let legal = move_gen.legal_moves(pos)
  let candidates =
    list.filter(legal, fn(m) {
      let is_pawn = case board_piece_at(pos, m.from) {
        Some(Pawn) -> True
        _ -> False
      }
      let matches_dest = m.to == dest
      let matches_file = case from_file {
        None -> True
        Some(f) -> m.from.file == f
      }
      let matches_promo = case promotion {
        None -> option.is_none(m.promotion)
        Some(p) -> m.promotion == Some(p)
      }
      is_pawn && matches_dest && matches_file && matches_promo
    })

  case candidates {
    [m] -> Ok(m)
    [] -> Error(NoMatchingMove(san))
    _ -> Error(AmbiguousMove(san))
  }
}

fn extract_promotion(chars: List(String)) -> #(List(String), Option(Piece)) {
  // Look for =Q, =R, =B, =N at end
  let rev = list.reverse(chars)
  case rev {
    [promo_char, "=", ..rest] ->
      case promotion_from_letter(promo_char) {
        Ok(piece) -> #(list.reverse(rest), Some(piece))
        Error(_) -> #(chars, None)
      }
    _ -> #(chars, None)
  }
}

fn promotion_from_letter(s: String) -> Result(Piece, Nil) {
  case s {
    "Q" -> Ok(Queen)
    "R" -> Ok(Rook)
    "B" -> Ok(Bishop)
    "N" -> Ok(Knight)
    _ -> Error(Nil)
  }
}

fn piece_from_letter(
  san: String,
  chars: List(String),
) -> Result(Piece, SanError) {
  case chars {
    ["N", ..] -> Ok(Knight)
    ["B", ..] -> Ok(Bishop)
    ["R", ..] -> Ok(Rook)
    ["Q", ..] -> Ok(Queen)
    ["K", ..] -> Ok(King)
    _ -> Error(InvalidSan(san))
  }
}

fn parse_square_chars(
  san: String,
  chars: List(String),
) -> Result(Square, SanError) {
  case chars {
    [f, r] ->
      case square.from_string(f <> r) {
        Ok(sq) -> Ok(sq)
        Error(_) -> Error(InvalidSan(san))
      }
    _ -> Error(InvalidSan(san))
  }
}

fn parse_file_char(san: String, c: String) -> Result(square.File, SanError) {
  case c {
    "a" -> Ok(square.A)
    "b" -> Ok(square.B)
    "c" -> Ok(square.C)
    "d" -> Ok(square.D)
    "e" -> Ok(square.E)
    "f" -> Ok(square.F)
    "g" -> Ok(square.G)
    "h" -> Ok(square.H)
    _ -> Error(InvalidSan(san))
  }
}

fn is_uppercase(s: String) -> Bool {
  s == string.uppercase(s) && s != string.lowercase(s)
}

fn filter_disambiguation(
  san: String,
  candidates: List(Move),
  disambig_chars: List(String),
) -> Result(Move, SanError) {
  case disambig_chars {
    [] ->
      case candidates {
        [m] -> Ok(m)
        [] -> Error(NoMatchingMove(san))
        _ -> Error(AmbiguousMove(san))
      }
    [file_char] -> {
      case parse_file_char(san, file_char) {
        Ok(file) -> {
          let filtered = list.filter(candidates, fn(m) { m.from.file == file })
          case filtered {
            [m] -> Ok(m)
            [] -> Error(NoMatchingMove(san))
            _ -> Error(AmbiguousMove(san))
          }
        }
        Error(_) -> {
          // Could be a rank digit
          case parse_rank_char(san, file_char) {
            Ok(rank) -> {
              let filtered =
                list.filter(candidates, fn(m) { m.from.rank == rank })
              case filtered {
                [m] -> Ok(m)
                [] -> Error(NoMatchingMove(san))
                _ -> Error(AmbiguousMove(san))
              }
            }
            Error(e) -> Error(e)
          }
        }
      }
    }
    [f, r] -> {
      // Both file and rank disambiguation
      use file <- result.try(parse_file_char(san, f))
      use rank <- result.try(parse_rank_char(san, r))
      let filtered =
        list.filter(candidates, fn(m) {
          m.from.file == file && m.from.rank == rank
        })
      case filtered {
        [m] -> Ok(m)
        [] -> Error(NoMatchingMove(san))
        _ -> Error(AmbiguousMove(san))
      }
    }
    _ -> Error(InvalidSan(san))
  }
}

fn parse_rank_char(san: String, c: String) -> Result(square.Rank, SanError) {
  case c {
    "1" -> Ok(square.R1)
    "2" -> Ok(square.R2)
    "3" -> Ok(square.R3)
    "4" -> Ok(square.R4)
    "5" -> Ok(square.R5)
    "6" -> Ok(square.R6)
    "7" -> Ok(square.R7)
    "8" -> Ok(square.R8)
    _ -> Error(InvalidSan(san))
  }
}

fn board_piece_at(pos: Position, sq: Square) -> Option(Piece) {
  case board_get(pos, sq) {
    Some(cp) -> Some(cp.piece)
    None -> None
  }
}

import chesscli/chess/board

fn board_get(
  pos: Position,
  sq: Square,
) -> Option(piece.ColoredPiece) {
  board.get(pos.board, sq)
}

// --- SAN formatting ---

fn format_standard_move(m: Move, pos: Position) -> String {
  let piece = board_piece_at(pos, m.from)
  case piece {
    Some(Pawn) -> format_pawn_san(m, pos)
    Some(p) -> format_piece_san(m, pos, p)
    None -> "???"
  }
}

fn format_pawn_san(m: Move, _pos: Position) -> String {
  let is_capture =
    square.file_to_int(m.from.file) != square.file_to_int(m.to.file)
  let base = case is_capture {
    True -> square.file_to_string(m.from.file) <> "x" <> square.to_string(m.to)
    False -> square.to_string(m.to)
  }
  case m.promotion {
    None -> base
    Some(p) -> base <> "=" <> piece_letter(p)
  }
}

fn format_piece_san(m: Move, pos: Position, piece: Piece) -> String {
  let letter = piece_letter(piece)
  let dest = square.to_string(m.to)
  let is_capture = case board_get(pos, m.to) {
    Some(_) -> True
    None -> False
  }
  let capture_str = case is_capture {
    True -> "x"
    False -> ""
  }

  // Check disambiguation
  let legal = move_gen.legal_moves(pos)
  let same_piece_same_dest =
    list.filter(legal, fn(other) {
      other.to == m.to
      && other.from != m.from
      && !other.is_castling
      && board_piece_at(pos, other.from) == Some(piece)
    })

  let disambig = case same_piece_same_dest {
    [] -> ""
    others -> {
      let same_file =
        list.any(others, fn(o) { o.from.file == m.from.file })
      let same_rank =
        list.any(others, fn(o) { o.from.rank == m.from.rank })
      case same_file, same_rank {
        True, True ->
          square.file_to_string(m.from.file)
          <> square.rank_to_string(m.from.rank)
        False, _ -> square.file_to_string(m.from.file)
        _, _ -> square.rank_to_string(m.from.rank)
      }
    }
  }

  letter <> disambig <> capture_str <> dest
}

fn piece_letter(piece: Piece) -> String {
  case piece {
    King -> "K"
    Queen -> "Q"
    Rook -> "R"
    Bishop -> "B"
    Knight -> "N"
    Pawn -> ""
  }
}

fn add_check_suffix(san: String, m: Move, pos: Position) -> String {
  let new_pos = move.apply(pos, m)
  case move_gen.is_in_check(new_pos, new_pos.active_color) {
    True ->
      case move_gen.game_status(new_pos) {
        move_gen.Checkmate -> san <> "#"
        _ -> san <> "+"
      }
    False -> san
  }
}
