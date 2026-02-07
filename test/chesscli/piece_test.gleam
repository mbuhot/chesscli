import chesscli/chess/color.{Black, White}
import chesscli/chess/piece.{
  Bishop, ColoredPiece, King, Knight, Pawn, Queen, Rook,
}

pub fn to_unicode_white_king_test() {
  assert piece.to_unicode(ColoredPiece(White, King)) == "♚"
}

pub fn to_unicode_white_queen_test() {
  assert piece.to_unicode(ColoredPiece(White, Queen)) == "♛"
}

pub fn to_unicode_white_rook_test() {
  assert piece.to_unicode(ColoredPiece(White, Rook)) == "♜"
}

pub fn to_unicode_white_bishop_test() {
  assert piece.to_unicode(ColoredPiece(White, Bishop)) == "♝"
}

pub fn to_unicode_white_knight_test() {
  assert piece.to_unicode(ColoredPiece(White, Knight)) == "♞"
}

pub fn to_unicode_white_pawn_test() {
  assert piece.to_unicode(ColoredPiece(White, Pawn)) == "♟"
}

pub fn to_unicode_black_king_test() {
  assert piece.to_unicode(ColoredPiece(Black, King)) == "♚"
}

pub fn to_unicode_black_queen_test() {
  assert piece.to_unicode(ColoredPiece(Black, Queen)) == "♛"
}

pub fn to_unicode_black_rook_test() {
  assert piece.to_unicode(ColoredPiece(Black, Rook)) == "♜"
}

pub fn to_unicode_black_bishop_test() {
  assert piece.to_unicode(ColoredPiece(Black, Bishop)) == "♝"
}

pub fn to_unicode_black_knight_test() {
  assert piece.to_unicode(ColoredPiece(Black, Knight)) == "♞"
}

pub fn to_unicode_black_pawn_test() {
  assert piece.to_unicode(ColoredPiece(Black, Pawn)) == "♟"
}

pub fn to_fen_char_white_pieces_test() {
  assert piece.to_fen_char(ColoredPiece(White, King)) == "K"
  assert piece.to_fen_char(ColoredPiece(White, Queen)) == "Q"
  assert piece.to_fen_char(ColoredPiece(White, Rook)) == "R"
  assert piece.to_fen_char(ColoredPiece(White, Bishop)) == "B"
  assert piece.to_fen_char(ColoredPiece(White, Knight)) == "N"
  assert piece.to_fen_char(ColoredPiece(White, Pawn)) == "P"
}

pub fn to_fen_char_black_pieces_test() {
  assert piece.to_fen_char(ColoredPiece(Black, King)) == "k"
  assert piece.to_fen_char(ColoredPiece(Black, Queen)) == "q"
  assert piece.to_fen_char(ColoredPiece(Black, Rook)) == "r"
  assert piece.to_fen_char(ColoredPiece(Black, Bishop)) == "b"
  assert piece.to_fen_char(ColoredPiece(Black, Knight)) == "n"
  assert piece.to_fen_char(ColoredPiece(Black, Pawn)) == "p"
}

pub fn from_fen_char_white_pieces_test() {
  assert piece.from_fen_char("K") == Ok(ColoredPiece(White, King))
  assert piece.from_fen_char("Q") == Ok(ColoredPiece(White, Queen))
  assert piece.from_fen_char("R") == Ok(ColoredPiece(White, Rook))
  assert piece.from_fen_char("B") == Ok(ColoredPiece(White, Bishop))
  assert piece.from_fen_char("N") == Ok(ColoredPiece(White, Knight))
  assert piece.from_fen_char("P") == Ok(ColoredPiece(White, Pawn))
}

pub fn from_fen_char_black_pieces_test() {
  assert piece.from_fen_char("k") == Ok(ColoredPiece(Black, King))
  assert piece.from_fen_char("q") == Ok(ColoredPiece(Black, Queen))
  assert piece.from_fen_char("r") == Ok(ColoredPiece(Black, Rook))
  assert piece.from_fen_char("b") == Ok(ColoredPiece(Black, Bishop))
  assert piece.from_fen_char("n") == Ok(ColoredPiece(Black, Knight))
  assert piece.from_fen_char("p") == Ok(ColoredPiece(Black, Pawn))
}

pub fn from_fen_char_invalid_test() {
  assert piece.from_fen_char("x") == Error(Nil)
  assert piece.from_fen_char("1") == Error(Nil)
  assert piece.from_fen_char("") == Error(Nil)
}

pub fn value_queen_test() {
  assert piece.value(Queen) == 9
}

pub fn value_rook_test() {
  assert piece.value(Rook) == 5
}

pub fn value_bishop_test() {
  assert piece.value(Bishop) == 3
}

pub fn value_knight_test() {
  assert piece.value(Knight) == 3
}

pub fn value_pawn_test() {
  assert piece.value(Pawn) == 1
}

pub fn value_king_test() {
  assert piece.value(King) == 0
}
