//// Defines the six chess piece types and pairs them with a color, providing
//// conversions to Unicode glyphs for TUI rendering and FEN characters for
//// position serialization.

import chesscli/chess/color.{type Color, Black, White}

/// The six distinct piece types in standard chess.
pub type Piece {
  King
  Queen
  Rook
  Bishop
  Knight
  Pawn
}

/// A piece owned by a specific side, the fundamental unit placed on the board.
pub type ColoredPiece {
  ColoredPiece(color: Color, piece: Piece)
}

/// Returns the filled Unicode glyph for display. Both colors use the same
/// filled shapes (♚♛♜♝♞♟) — the renderer differentiates by foreground color.
pub fn to_unicode(cp: ColoredPiece) -> String {
  case cp.piece {
    King -> "♚"
    Queen -> "♛"
    Rook -> "♜"
    Bishop -> "♝"
    Knight -> "♞"
    Pawn -> "♟"
  }
}

/// Converts to the single-character FEN representation (uppercase = White, lowercase = Black).
pub fn to_fen_char(cp: ColoredPiece) -> String {
  case cp {
    ColoredPiece(White, King) -> "K"
    ColoredPiece(White, Queen) -> "Q"
    ColoredPiece(White, Rook) -> "R"
    ColoredPiece(White, Bishop) -> "B"
    ColoredPiece(White, Knight) -> "N"
    ColoredPiece(White, Pawn) -> "P"
    ColoredPiece(Black, King) -> "k"
    ColoredPiece(Black, Queen) -> "q"
    ColoredPiece(Black, Rook) -> "r"
    ColoredPiece(Black, Bishop) -> "b"
    ColoredPiece(Black, Knight) -> "n"
    ColoredPiece(Black, Pawn) -> "p"
  }
}

/// Standard material value for a piece type (Q=9, R=5, B=3, N=3, P=1, K=0).
pub fn value(p: Piece) -> Int {
  case p {
    Queen -> 9
    Rook -> 5
    Bishop -> 3
    Knight -> 3
    Pawn -> 1
    King -> 0
  }
}

/// Parses a FEN piece character back into a ColoredPiece, returning Error(Nil)
/// for unrecognized characters.
pub fn from_fen_char(char: String) -> Result(ColoredPiece, Nil) {
  case char {
    "K" -> Ok(ColoredPiece(White, King))
    "Q" -> Ok(ColoredPiece(White, Queen))
    "R" -> Ok(ColoredPiece(White, Rook))
    "B" -> Ok(ColoredPiece(White, Bishop))
    "N" -> Ok(ColoredPiece(White, Knight))
    "P" -> Ok(ColoredPiece(White, Pawn))
    "k" -> Ok(ColoredPiece(Black, King))
    "q" -> Ok(ColoredPiece(Black, Queen))
    "r" -> Ok(ColoredPiece(Black, Rook))
    "b" -> Ok(ColoredPiece(Black, Bishop))
    "n" -> Ok(ColoredPiece(Black, Knight))
    "p" -> Ok(ColoredPiece(Black, Pawn))
    _ -> Error(Nil)
  }
}
