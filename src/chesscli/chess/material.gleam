//// Computes captured pieces and material advantage by comparing the current
//// board against starting material, and formats the result for display.

import chesscli/chess/board.{type Board}
import chesscli/chess/color.{Black, White}
import chesscli/chess/piece.{
  type Piece, Bishop, ColoredPiece, King, Knight, Pawn, Queen, Rook,
}
import gleam/dict
import gleam/int
import gleam/list
import gleam/string

/// Pieces captured by one side, with their combined material value.
pub type CapturedMaterial {
  CapturedMaterial(pieces: List(Piece), total_value: Int)
}

/// Summary of both sides' captures and the overall material advantage.
pub type MaterialSummary {
  MaterialSummary(
    white_captures: CapturedMaterial,
    black_captures: CapturedMaterial,
    /// Positive means white leads in material.
    advantage: Int,
  )
}

/// Computes what each side has captured by diffing the board against
/// starting material. Captured pieces are sorted by value ascending.
pub fn from_board(board: Board) -> MaterialSummary {
  let starting = [
    #(Pawn, 8),
    #(Bishop, 2),
    #(Knight, 2),
    #(Rook, 2),
    #(Queen, 1),
  ]

  let white_remaining = count_pieces(board, White)
  let black_remaining = count_pieces(board, Black)

  let white_captures = compute_captures(starting, black_remaining)
  let black_captures = compute_captures(starting, white_remaining)

  MaterialSummary(
    white_captures: white_captures,
    black_captures: black_captures,
    advantage: white_captures.total_value - black_captures.total_value,
  )
}

/// Formats captured pieces as unicode glyphs with an optional advantage suffix.
/// Returns empty string when there are no captures.
pub fn format_captures(captures: CapturedMaterial, advantage: Int) -> String {
  case captures.pieces {
    [] -> ""
    pieces -> {
      let glyphs =
        list.map(pieces, fn(p) { piece.to_unicode(ColoredPiece(Black, p)) })
        |> string.concat
      case advantage > 0 {
        True -> glyphs <> " +" <> int.to_string(advantage)
        False -> glyphs
      }
    }
  }
}

fn count_pieces(
  board: Board,
  color: color.Color,
) -> List(#(Piece, Int)) {
  let counts =
    dict.values(board.pieces)
    |> list.filter(fn(cp) { cp.color == color })
    |> list.fold(dict.new(), fn(acc, cp) {
      let current = case dict.get(acc, cp.piece) {
        Ok(n) -> n
        Error(_) -> 0
      }
      dict.insert(acc, cp.piece, current + 1)
    })

  [
    #(Queen, dict_get_or_zero(counts, Queen)),
    #(Rook, dict_get_or_zero(counts, Rook)),
    #(Bishop, dict_get_or_zero(counts, Bishop)),
    #(Knight, dict_get_or_zero(counts, Knight)),
    #(Pawn, dict_get_or_zero(counts, Pawn)),
    #(King, dict_get_or_zero(counts, King)),
  ]
}

fn dict_get_or_zero(d: dict.Dict(Piece, Int), key: Piece) -> Int {
  case dict.get(d, key) {
    Ok(n) -> n
    Error(_) -> 0
  }
}

fn compute_captures(
  starting: List(#(Piece, Int)),
  remaining: List(#(Piece, Int)),
) -> CapturedMaterial {
  let remaining_map = dict.from_list(remaining)
  let pieces =
    list.flat_map(starting, fn(entry) {
      let #(p, start_count) = entry
      let current = dict_get_or_zero(remaining_map, p)
      let missing = int.max(start_count - current, 0)
      list.repeat(p, missing)
    })

  let total = list.fold(pieces, 0, fn(acc, p) { acc + piece.value(p) })
  CapturedMaterial(pieces: pieces, total_value: total)
}
