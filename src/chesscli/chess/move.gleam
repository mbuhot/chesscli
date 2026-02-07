//// Representation of a chess move and the logic to apply it to a position.
//// Handles all move types: normal, capture, castling, en passant, and promotion.

import chesscli/chess/board
import chesscli/chess/color.{Black, White}
import chesscli/chess/piece.{
  type Piece, Bishop, ColoredPiece, King, Knight, Pawn, Queen, Rook,
}
import chesscli/chess/position.{type Position, CastlingRights, Position}
import chesscli/chess/square.{type Square, Square}
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// A chess move linking an origin and destination square, with flags for
/// special move types (castling, en passant) and an optional promotion piece.
pub type Move {
  Move(
    from: Square,
    to: Square,
    promotion: Option(Piece),
    is_castling: Bool,
    is_en_passant: Bool,
  )
}

/// Encode a move in UCI long algebraic notation (e.g. "e2e4", "e7e8q").
pub fn to_uci(move: Move) -> String {
  let base = square.to_string(move.from) <> square.to_string(move.to)
  case move.promotion {
    None -> base
    Some(piece) -> base <> promotion_to_string(piece)
  }
}

/// Parse a UCI long algebraic notation string into a Move.
/// Does not validate legality; only decodes the from/to squares and promotion.
pub fn from_uci(s: String) -> Result(Move, Nil) {
  let chars = string.to_graphemes(s)
  case chars {
    [f1, r1, f2, r2] -> {
      use from <- result.try(square.from_string(f1 <> r1))
      use to <- result.try(square.from_string(f2 <> r2))
      Ok(Move(from:, to:, promotion: None, is_castling: False, is_en_passant: False))
    }
    [f1, r1, f2, r2, p] -> {
      use from <- result.try(square.from_string(f1 <> r1))
      use to <- result.try(square.from_string(f2 <> r2))
      use promo <- result.try(promotion_from_string(p))
      Ok(Move(from:, to:, promotion: Some(promo), is_castling: False, is_en_passant: False))
    }
    _ -> Error(Nil)
  }
}

/// Apply a move to a position, returning the new position.
/// Handles piece movement, captures, castling, en passant, promotion,
/// and updates castling rights, en passant square, and move clocks.
pub fn apply(pos: Position, move: Move) -> Position {
  let moved_piece = board.get(pos.board, move.from)
  let is_capture = case board.get(pos.board, move.to) {
    Some(_) -> True
    None -> move.is_en_passant
  }

  // Move the piece on the board
  let new_board = apply_board_move(pos, move, moved_piece)

  // Update castling rights
  let new_castling = update_castling(pos.castling, move)

  // Update en passant square
  let new_en_passant = update_en_passant(move, moved_piece)

  // Update clocks
  let is_pawn_move = case moved_piece {
    Some(ColoredPiece(_, Pawn)) -> True
    _ -> False
  }
  let new_halfmove = case is_pawn_move || is_capture {
    True -> 0
    False -> pos.halfmove_clock + 1
  }
  let new_fullmove = case pos.active_color {
    Black -> pos.fullmove_number + 1
    White -> pos.fullmove_number
  }

  Position(
    board: new_board,
    active_color: color.opposite(pos.active_color),
    castling: new_castling,
    en_passant: new_en_passant,
    halfmove_clock: new_halfmove,
    fullmove_number: new_fullmove,
  )
}

fn apply_board_move(
  pos: Position,
  move: Move,
  moved_piece: Option(piece.ColoredPiece),
) -> board.Board {
  let piece_to_place = case move.promotion, moved_piece {
    Some(promo), Some(ColoredPiece(c, _)) -> ColoredPiece(c, promo)
    _, Some(p) -> p
    _, None -> panic as "no piece at from square"
  }

  let b =
    pos.board
    |> board.remove(move.from)
    |> board.set(move.to, piece_to_place)

  // Handle en passant capture: remove the captured pawn
  let b = case move.is_en_passant, moved_piece {
    True, Some(ColoredPiece(White, Pawn)) -> {
      // White captures en passant: remove pawn on rank below target
      let assert Ok(rank) = square.rank_from_int(square.rank_to_int(move.to.rank) - 1)
      board.remove(b, Square(move.to.file, rank))
    }
    True, Some(ColoredPiece(Black, Pawn)) -> {
      // Black captures en passant: remove pawn on rank above target
      let assert Ok(rank) = square.rank_from_int(square.rank_to_int(move.to.rank) + 1)
      board.remove(b, Square(move.to.file, rank))
    }
    _, _ -> b
  }

  // Handle castling: move the rook
  let b = case move.is_castling, moved_piece {
    True, Some(ColoredPiece(White, King)) ->
      apply_castling_rook(b, move, square.R1)
    True, Some(ColoredPiece(Black, King)) ->
      apply_castling_rook(b, move, square.R8)
    _, _ -> b
  }

  b
}

fn apply_castling_rook(
  b: board.Board,
  move: Move,
  rank: square.Rank,
) -> board.Board {
  case square.file_to_int(move.to.file) {
    // Kingside castling (king goes to g-file): move rook from h to f
    6 -> {
      let assert Some(rook) = board.get(b, Square(square.H, rank))
      b
      |> board.remove(Square(square.H, rank))
      |> board.set(Square(square.F, rank), rook)
    }
    // Queenside castling (king goes to c-file): move rook from a to d
    2 -> {
      let assert Some(rook) = board.get(b, Square(square.A, rank))
      b
      |> board.remove(Square(square.A, rank))
      |> board.set(Square(square.D, rank), rook)
    }
    _ -> b
  }
}

fn update_castling(
  castling: position.CastlingRights,
  move: Move,
) -> position.CastlingRights {
  let from_idx = square.to_index(move.from)
  let to_idx = square.to_index(move.to)

  // King moves lose both castling rights for that color
  // Rook moves from corner lose that side's castling right
  // Captures on rook squares also lose castling rights
  CastlingRights(
    white_kingside: castling.white_kingside
      && from_idx != 4
      && from_idx != 7
      && to_idx != 7,
    white_queenside: castling.white_queenside
      && from_idx != 4
      && from_idx != 0
      && to_idx != 0,
    black_kingside: castling.black_kingside
      && from_idx != 60
      && from_idx != 63
      && to_idx != 63,
    black_queenside: castling.black_queenside
      && from_idx != 60
      && from_idx != 56
      && to_idx != 56,
  )
}

fn update_en_passant(
  move: Move,
  moved_piece: Option(piece.ColoredPiece),
) -> Option(Square) {
  case moved_piece {
    Some(ColoredPiece(White, Pawn)) -> {
      // White double push: from rank 2 to rank 4
      case
        square.rank_to_int(move.from.rank) == 1
        && square.rank_to_int(move.to.rank) == 3
      {
        True -> Some(Square(move.from.file, square.R3))
        False -> None
      }
    }
    Some(ColoredPiece(Black, Pawn)) -> {
      // Black double push: from rank 7 to rank 5
      case
        square.rank_to_int(move.from.rank) == 6
        && square.rank_to_int(move.to.rank) == 4
      {
        True -> Some(Square(move.from.file, square.R6))
        False -> None
      }
    }
    _ -> None
  }
}

fn promotion_to_string(piece: Piece) -> String {
  case piece {
    Queen -> "q"
    Rook -> "r"
    Bishop -> "b"
    Knight -> "n"
    _ -> ""
  }
}

fn promotion_from_string(s: String) -> Result(Piece, Nil) {
  case s {
    "q" -> Ok(Queen)
    "r" -> Ok(Rook)
    "b" -> Ok(Bishop)
    "n" -> Ok(Knight)
    _ -> Error(Nil)
  }
}
