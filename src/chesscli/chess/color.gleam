//// Represents the two sides in a chess game, used throughout the engine
//// to track whose turn it is, which side owns a piece, and casting rights.

/// The side a player controls in a game of chess.
pub type Color {
  White
  Black
}

/// Returns the other color, used for alternating turns and identifying opponents.
pub fn opposite(color: Color) -> Color {
  case color {
    White -> Black
    Black -> White
  }
}

/// Produces a human-readable label for display in the TUI and status messages.
pub fn to_string(color: Color) -> String {
  case color {
    White -> "White"
    Black -> "Black"
  }
}
