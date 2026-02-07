import chesscli/chess/color.{Black, White}
import chesscli/chess/piece.{
  type ColoredPiece, Bishop, ColoredPiece, King, Knight, Pawn, Queen, Rook,
}
import chesscli/chess/square.{type Square, A, B, C, D, E, F, G, H, R1, R2, R7, R8, Square}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}

pub type Board {
  Board(pieces: Dict(Square, ColoredPiece))
}

pub fn empty() -> Board {
  Board(pieces: dict.new())
}

pub fn initial() -> Board {
  let back_rank = [Rook, Knight, Bishop, Queen, King, Bishop, Knight, Rook]
  let files = [A, B, C, D, E, F, G, H]

  let pieces =
    []
    |> add_rank(files, back_rank, White, R1)
    |> add_pawns(files, White, R2)
    |> add_pawns(files, Black, R7)
    |> add_rank(files, back_rank, Black, R8)

  Board(pieces: dict.from_list(pieces))
}

pub fn get(board: Board, sq: Square) -> Option(ColoredPiece) {
  case dict.get(board.pieces, sq) {
    Ok(piece) -> Some(piece)
    Error(_) -> None
  }
}

pub fn set(board: Board, sq: Square, piece: ColoredPiece) -> Board {
  Board(pieces: dict.insert(board.pieces, sq, piece))
}

pub fn remove(board: Board, sq: Square) -> Board {
  Board(pieces: dict.delete(board.pieces, sq))
}

fn add_rank(
  acc: List(#(Square, ColoredPiece)),
  files: List(square.File),
  pieces: List(piece.Piece),
  color: color.Color,
  rank: square.Rank,
) -> List(#(Square, ColoredPiece)) {
  list.zip(files, pieces)
  |> list.fold(acc, fn(acc, pair) {
    let #(file, piece) = pair
    [#(Square(file, rank), ColoredPiece(color, piece)), ..acc]
  })
}

fn add_pawns(
  acc: List(#(Square, ColoredPiece)),
  files: List(square.File),
  color: color.Color,
  rank: square.Rank,
) -> List(#(Square, ColoredPiece)) {
  list.fold(files, acc, fn(acc, file) {
    [#(Square(file, rank), ColoredPiece(color, Pawn)), ..acc]
  })
}
