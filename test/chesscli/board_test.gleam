import chesscli/chess/board
import chesscli/chess/color.{Black, White}
import chesscli/chess/piece.{
  Bishop, ColoredPiece, King, Knight, Pawn, Queen, Rook,
}
import chesscli/chess/square.{A, B, C, D, E, F, G, H, R1, R2, R7, R8, Square}
import gleam/dict
import gleam/option.{None, Some}

pub fn empty_board_has_no_pieces_test() {
  let b = board.empty()
  assert dict.size(b.pieces) == 0
}

pub fn get_empty_square_returns_none_test() {
  let b = board.empty()
  assert board.get(b, Square(E, R1)) == None
}

pub fn set_and_get_piece_test() {
  let b = board.empty()
  let wk = ColoredPiece(White, King)
  let b = board.set(b, Square(E, R1), wk)
  assert board.get(b, Square(E, R1)) == Some(wk)
}

pub fn remove_piece_test() {
  let b = board.empty()
  let wk = ColoredPiece(White, King)
  let b = board.set(b, Square(E, R1), wk)
  let b = board.remove(b, Square(E, R1))
  assert board.get(b, Square(E, R1)) == None
}

pub fn remove_empty_square_test() {
  let b = board.empty()
  let b = board.remove(b, Square(E, R1))
  assert board.get(b, Square(E, R1)) == None
}

pub fn initial_board_has_32_pieces_test() {
  let b = board.initial()
  assert dict.size(b.pieces) == 32
}

pub fn initial_board_white_back_rank_test() {
  let b = board.initial()
  assert board.get(b, Square(A, R1)) == Some(ColoredPiece(White, Rook))
  assert board.get(b, Square(B, R1)) == Some(ColoredPiece(White, Knight))
  assert board.get(b, Square(C, R1)) == Some(ColoredPiece(White, Bishop))
  assert board.get(b, Square(D, R1)) == Some(ColoredPiece(White, Queen))
  assert board.get(b, Square(E, R1)) == Some(ColoredPiece(White, King))
  assert board.get(b, Square(F, R1)) == Some(ColoredPiece(White, Bishop))
  assert board.get(b, Square(G, R1)) == Some(ColoredPiece(White, Knight))
  assert board.get(b, Square(H, R1)) == Some(ColoredPiece(White, Rook))
}

pub fn initial_board_white_pawns_test() {
  let b = board.initial()
  assert board.get(b, Square(A, R2)) == Some(ColoredPiece(White, Pawn))
  assert board.get(b, Square(B, R2)) == Some(ColoredPiece(White, Pawn))
  assert board.get(b, Square(C, R2)) == Some(ColoredPiece(White, Pawn))
  assert board.get(b, Square(D, R2)) == Some(ColoredPiece(White, Pawn))
  assert board.get(b, Square(E, R2)) == Some(ColoredPiece(White, Pawn))
  assert board.get(b, Square(F, R2)) == Some(ColoredPiece(White, Pawn))
  assert board.get(b, Square(G, R2)) == Some(ColoredPiece(White, Pawn))
  assert board.get(b, Square(H, R2)) == Some(ColoredPiece(White, Pawn))
}

pub fn initial_board_black_back_rank_test() {
  let b = board.initial()
  assert board.get(b, Square(A, R8)) == Some(ColoredPiece(Black, Rook))
  assert board.get(b, Square(B, R8)) == Some(ColoredPiece(Black, Knight))
  assert board.get(b, Square(C, R8)) == Some(ColoredPiece(Black, Bishop))
  assert board.get(b, Square(D, R8)) == Some(ColoredPiece(Black, Queen))
  assert board.get(b, Square(E, R8)) == Some(ColoredPiece(Black, King))
  assert board.get(b, Square(F, R8)) == Some(ColoredPiece(Black, Bishop))
  assert board.get(b, Square(G, R8)) == Some(ColoredPiece(Black, Knight))
  assert board.get(b, Square(H, R8)) == Some(ColoredPiece(Black, Rook))
}

pub fn initial_board_black_pawns_test() {
  let b = board.initial()
  assert board.get(b, Square(A, R7)) == Some(ColoredPiece(Black, Pawn))
  assert board.get(b, Square(H, R7)) == Some(ColoredPiece(Black, Pawn))
}

pub fn initial_board_empty_squares_test() {
  let b = board.initial()
  assert board.get(b, Square(E, square.R4)) == None
  assert board.get(b, Square(D, square.R5)) == None
}
