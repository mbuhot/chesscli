//// Captures the full game state needed to determine all legal moves.
//// Combines the board with side to move, castling rights, en passant,
//// and move counters -- everything encoded in a FEN string.

import chesscli/chess/board.{type Board}
import chesscli/chess/color.{type Color}
import chesscli/chess/square.{type Square}
import gleam/option.{type Option}

/// Tracks which castling moves are still legal. Kingside (O-O) and queenside
/// (O-O-O) are tracked separately because each rook can be captured or moved
/// independently - e.g. moving the a1 rook loses queenside castling rights
/// while kingside remains available.
pub type CastlingRights {
  CastlingRights(
    white_kingside: Bool,
    white_queenside: Bool,
    black_kingside: Bool,
    black_queenside: Bool,
  )
}

/// The complete game state at a single point in time.
/// Contains everything needed to determine all legal moves from this position.
pub type Position {
  Position(
    board: Board,
    active_color: Color,
    castling: CastlingRights,
    en_passant: Option(Square),
    /// Number of half-moves (plies) since the last pawn advance or capture.
    /// Used for the 50-move draw rule: the game is drawn when this reaches 100.
    halfmove_clock: Int,
    /// Incremented after each Black move. Starts at 1 and represents the
    /// current move number in standard chess notation (e.g. "1. e4 e5 2. Nf3").
    fullmove_number: Int,
  )
}

/// Creates the standard starting position: all pieces placed, White to move,
/// all castling rights available, no en passant, and move counters at zero/one.
pub fn initial() -> Position {
  Position(
    board: board.initial(),
    active_color: color.White,
    castling: CastlingRights(
      white_kingside: True,
      white_queenside: True,
      black_kingside: True,
      black_queenside: True,
    ),
    en_passant: option.None,
    halfmove_clock: 0,
    fullmove_number: 1,
  )
}
