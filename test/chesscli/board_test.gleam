import chesscli/chess/board
import chesscli/chess/color.{Black, White}
import chesscli/chess/piece.{
  Bishop, ColoredPiece, King, Knight, Pawn, Queen, Rook,
}
import chesscli/chess/square
import gleam/dict
import gleam/option.{None, Some}

pub fn empty_board_has_no_pieces_test() {
  let b = board.empty()
  assert dict.size(b.pieces) == 0
}

pub fn get_empty_square_returns_none_test() {
  let b = board.empty()
  assert board.get(b, square.e1) == None
}

pub fn set_and_get_piece_test() {
  let b = board.empty()
  let wk = ColoredPiece(White, King)
  let b = board.set(b, square.e1, wk)
  assert board.get(b, square.e1) == Some(wk)
}

pub fn remove_piece_test() {
  let b = board.empty()
  let wk = ColoredPiece(White, King)
  let b = board.set(b, square.e1, wk)
  let b = board.remove(b, square.e1)
  assert board.get(b, square.e1) == None
}

pub fn remove_empty_square_test() {
  let b = board.empty()
  let b = board.remove(b, square.e1)
  assert board.get(b, square.e1) == None
}

pub fn initial_board_has_32_pieces_test() {
  let b = board.initial()
  assert dict.size(b.pieces) == 32
}

pub fn initial_board_white_back_rank_test() {
  let b = board.initial()
  assert board.get(b, square.a1) == Some(ColoredPiece(White, Rook))
  assert board.get(b, square.b1) == Some(ColoredPiece(White, Knight))
  assert board.get(b, square.c1) == Some(ColoredPiece(White, Bishop))
  assert board.get(b, square.d1) == Some(ColoredPiece(White, Queen))
  assert board.get(b, square.e1) == Some(ColoredPiece(White, King))
  assert board.get(b, square.f1) == Some(ColoredPiece(White, Bishop))
  assert board.get(b, square.g1) == Some(ColoredPiece(White, Knight))
  assert board.get(b, square.h1) == Some(ColoredPiece(White, Rook))
}

pub fn initial_board_white_pawns_test() {
  let b = board.initial()
  assert board.get(b, square.a2) == Some(ColoredPiece(White, Pawn))
  assert board.get(b, square.b2) == Some(ColoredPiece(White, Pawn))
  assert board.get(b, square.c2) == Some(ColoredPiece(White, Pawn))
  assert board.get(b, square.d2) == Some(ColoredPiece(White, Pawn))
  assert board.get(b, square.e2) == Some(ColoredPiece(White, Pawn))
  assert board.get(b, square.f2) == Some(ColoredPiece(White, Pawn))
  assert board.get(b, square.g2) == Some(ColoredPiece(White, Pawn))
  assert board.get(b, square.h2) == Some(ColoredPiece(White, Pawn))
}

pub fn initial_board_black_back_rank_test() {
  let b = board.initial()
  assert board.get(b, square.a8) == Some(ColoredPiece(Black, Rook))
  assert board.get(b, square.b8) == Some(ColoredPiece(Black, Knight))
  assert board.get(b, square.c8) == Some(ColoredPiece(Black, Bishop))
  assert board.get(b, square.d8) == Some(ColoredPiece(Black, Queen))
  assert board.get(b, square.e8) == Some(ColoredPiece(Black, King))
  assert board.get(b, square.f8) == Some(ColoredPiece(Black, Bishop))
  assert board.get(b, square.g8) == Some(ColoredPiece(Black, Knight))
  assert board.get(b, square.h8) == Some(ColoredPiece(Black, Rook))
}

pub fn initial_board_black_pawns_test() {
  let b = board.initial()
  assert board.get(b, square.a7) == Some(ColoredPiece(Black, Pawn))
  assert board.get(b, square.h7) == Some(ColoredPiece(Black, Pawn))
}

pub fn initial_board_empty_squares_test() {
  let b = board.initial()
  assert board.get(b, square.e4) == None
  assert board.get(b, square.d5) == None
}
