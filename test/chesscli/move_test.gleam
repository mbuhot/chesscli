import chesscli/chess/board
import chesscli/chess/color.{Black, White}
import chesscli/chess/fen
import chesscli/chess/move.{Move}
import chesscli/chess/piece.{ColoredPiece, King, Knight, Pawn, Queen, Rook}
import chesscli/chess/position
import chesscli/chess/square
import gleam/option.{None, Some}

// --- to_uci tests ---

pub fn to_uci_simple_move_test() {
  let m = Move(from: square.e2, to: square.e4, promotion: None, is_castling: False, is_en_passant: False)
  assert move.to_uci(m) == "e2e4"
}

pub fn to_uci_with_promotion_test() {
  let m = Move(from: square.e7, to: square.e8, promotion: Some(Queen), is_castling: False, is_en_passant: False)
  assert move.to_uci(m) == "e7e8q"
}

pub fn to_uci_knight_promotion_test() {
  let m = Move(from: square.a7, to: square.a8, promotion: Some(Knight), is_castling: False, is_en_passant: False)
  assert move.to_uci(m) == "a7a8n"
}

// --- from_uci tests ---

pub fn from_uci_simple_move_test() {
  let assert Ok(m) = move.from_uci("e2e4")
  assert m.from == square.e2
  assert m.to == square.e4
  assert m.promotion == None
}

pub fn from_uci_with_promotion_test() {
  let assert Ok(m) = move.from_uci("e7e8q")
  assert m.from == square.e7
  assert m.to == square.e8
  assert m.promotion == Some(Queen)
}

pub fn from_uci_invalid_test() {
  assert move.from_uci("xyz") == Error(Nil)
}

pub fn from_uci_invalid_square_test() {
  assert move.from_uci("z9e4") == Error(Nil)
}

pub fn from_uci_roundtrip_test() {
  let m = Move(from: square.g1, to: square.f3, promotion: None, is_castling: False, is_en_passant: False)
  let assert Ok(parsed) = move.from_uci(move.to_uci(m))
  assert parsed.from == m.from
  assert parsed.to == m.to
  assert parsed.promotion == m.promotion
}

// --- apply tests ---

pub fn apply_simple_pawn_push_test() {
  let pos = position.initial()
  let m = Move(from: square.e2, to: square.e4, promotion: None, is_castling: False, is_en_passant: False)
  let new_pos = move.apply(pos, m)

  assert board.get(new_pos.board, square.e4) == Some(ColoredPiece(White, Pawn))
  assert board.get(new_pos.board, square.e2) == None
  assert new_pos.active_color == Black
  assert new_pos.en_passant == Some(square.e3)
  assert new_pos.halfmove_clock == 0
  assert new_pos.fullmove_number == 1
}

pub fn apply_knight_move_test() {
  let pos = position.initial()
  let m = Move(from: square.g1, to: square.f3, promotion: None, is_castling: False, is_en_passant: False)
  let new_pos = move.apply(pos, m)

  assert board.get(new_pos.board, square.f3) == Some(ColoredPiece(White, Knight))
  assert board.get(new_pos.board, square.g1) == None
  assert new_pos.en_passant == None
  assert new_pos.halfmove_clock == 1
}

pub fn apply_black_pawn_double_push_test() {
  let pos = position.initial()
  let e4 = Move(from: square.e2, to: square.e4, promotion: None, is_castling: False, is_en_passant: False)
  let pos = move.apply(pos, e4)

  let d5 = Move(from: square.d7, to: square.d5, promotion: None, is_castling: False, is_en_passant: False)
  let new_pos = move.apply(pos, d5)

  assert board.get(new_pos.board, square.d5) == Some(ColoredPiece(Black, Pawn))
  assert new_pos.active_color == White
  assert new_pos.en_passant == Some(square.d6)
  assert new_pos.fullmove_number == 2
}

pub fn apply_capture_resets_halfmove_test() {
  let assert Ok(pos) = fen.parse("rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2")
  let capture = Move(from: square.e4, to: square.d5, promotion: None, is_castling: False, is_en_passant: False)
  let new_pos = move.apply(pos, capture)

  assert board.get(new_pos.board, square.d5) == Some(ColoredPiece(White, Pawn))
  assert board.get(new_pos.board, square.e4) == None
  assert new_pos.halfmove_clock == 0
}

pub fn apply_en_passant_test() {
  let assert Ok(pos) = fen.parse("rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3")
  let ep = Move(from: square.e5, to: square.d6, promotion: None, is_castling: False, is_en_passant: True)
  let new_pos = move.apply(pos, ep)

  assert board.get(new_pos.board, square.d6) == Some(ColoredPiece(White, Pawn))
  assert board.get(new_pos.board, square.e5) == None
  assert board.get(new_pos.board, square.d5) == None
}

pub fn apply_promotion_test() {
  let assert Ok(pos) = fen.parse("4k3/4P3/8/8/8/8/8/4K3 w - - 0 1")
  let promo = Move(from: square.e7, to: square.e8, promotion: Some(Queen), is_castling: False, is_en_passant: False)
  let new_pos = move.apply(pos, promo)

  assert board.get(new_pos.board, square.e8) == Some(ColoredPiece(White, Queen))
  assert board.get(new_pos.board, square.e7) == None
}

pub fn apply_kingside_castling_white_test() {
  let assert Ok(pos) = fen.parse("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1")
  let castle = Move(from: square.e1, to: square.g1, promotion: None, is_castling: True, is_en_passant: False)
  let new_pos = move.apply(pos, castle)

  assert board.get(new_pos.board, square.g1) == Some(ColoredPiece(White, King))
  assert board.get(new_pos.board, square.f1) == Some(ColoredPiece(White, Rook))
  assert board.get(new_pos.board, square.e1) == None
  assert board.get(new_pos.board, square.h1) == None
  assert new_pos.castling.white_kingside == False
  assert new_pos.castling.white_queenside == False
}

pub fn apply_queenside_castling_white_test() {
  let assert Ok(pos) = fen.parse("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1")
  let castle = Move(from: square.e1, to: square.c1, promotion: None, is_castling: True, is_en_passant: False)
  let new_pos = move.apply(pos, castle)

  assert board.get(new_pos.board, square.c1) == Some(ColoredPiece(White, King))
  assert board.get(new_pos.board, square.d1) == Some(ColoredPiece(White, Rook))
  assert board.get(new_pos.board, square.e1) == None
  assert board.get(new_pos.board, square.a1) == None
}

pub fn apply_kingside_castling_black_test() {
  let assert Ok(pos) = fen.parse("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R b KQkq - 0 1")
  let castle = Move(from: square.e8, to: square.g8, promotion: None, is_castling: True, is_en_passant: False)
  let new_pos = move.apply(pos, castle)

  assert board.get(new_pos.board, square.g8) == Some(ColoredPiece(Black, King))
  assert board.get(new_pos.board, square.f8) == Some(ColoredPiece(Black, Rook))
  assert board.get(new_pos.board, square.e8) == None
  assert board.get(new_pos.board, square.h8) == None
  assert new_pos.castling.black_kingside == False
  assert new_pos.castling.black_queenside == False
}

pub fn apply_rook_move_loses_castling_test() {
  let assert Ok(pos) = fen.parse("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1")
  let m = Move(from: square.h1, to: square.h2, promotion: None, is_castling: False, is_en_passant: False)
  let new_pos = move.apply(pos, m)

  assert new_pos.castling.white_kingside == False
  assert new_pos.castling.white_queenside == True
  assert new_pos.castling.black_kingside == True
  assert new_pos.castling.black_queenside == True
}

pub fn apply_fen_roundtrip_after_e4_test() {
  let pos = position.initial()
  let e4 = Move(from: square.e2, to: square.e4, promotion: None, is_castling: False, is_en_passant: False)
  let new_pos = move.apply(pos, e4)
  assert fen.to_string(new_pos) == "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
}
