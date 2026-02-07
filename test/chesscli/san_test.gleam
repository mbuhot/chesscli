import chesscli/chess/fen
import chesscli/chess/move
import chesscli/chess/piece
import chesscli/chess/position.{type Position}
import chesscli/chess/san
import chesscli/chess/square
import gleam/option.{None, Some}

fn parse_fen(s: String) -> Position {
  let assert Ok(pos) = fen.parse(s)
  pos
}

// --- SAN parsing tests ---

pub fn parse_pawn_push_test() {
  let pos = position.initial()
  let assert Ok(m) = san.parse("e4", pos)
  assert m.from == square.e2
  assert m.to == square.e4
  assert m.promotion == None
}

pub fn parse_pawn_single_push_test() {
  let pos = position.initial()
  let assert Ok(m) = san.parse("e3", pos)
  assert m.from == square.e2
  assert m.to == square.e3
}

pub fn parse_knight_move_test() {
  let pos = position.initial()
  let assert Ok(m) = san.parse("Nf3", pos)
  assert m.from == square.g1
  assert m.to == square.f3
}

pub fn parse_pawn_capture_test() {
  let pos = parse_fen("4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1")
  let assert Ok(m) = san.parse("exd5", pos)
  assert m.from == square.e4
  assert m.to == square.d5
}

pub fn parse_kingside_castling_test() {
  let pos = parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1")
  let assert Ok(m) = san.parse("O-O", pos)
  assert m.from == square.e1
  assert m.to == square.g1
  assert m.is_castling == True
}

pub fn parse_queenside_castling_test() {
  let pos = parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1")
  let assert Ok(m) = san.parse("O-O-O", pos)
  assert m.from == square.e1
  assert m.to == square.c1
  assert m.is_castling == True
}

pub fn parse_promotion_test() {
  let pos = parse_fen("3k4/4P3/8/8/8/8/8/4K3 w - - 0 1")
  let assert Ok(m) = san.parse("e8=Q", pos)
  assert m.to == square.e8
  assert m.promotion == Some(piece.Queen)
}

pub fn parse_promotion_knight_test() {
  let pos = parse_fen("3k4/4P3/8/8/8/8/8/4K3 w - - 0 1")
  let assert Ok(m) = san.parse("e8=N", pos)
  assert m.to == square.e8
  assert m.promotion == Some(piece.Knight)
}

pub fn parse_capture_promotion_test() {
  let pos = parse_fen("3nk3/4P3/8/8/8/8/8/4K3 w - - 0 1")
  let assert Ok(m) = san.parse("exd8=Q", pos)
  assert m.from == square.e7
  assert m.to == square.d8
  assert m.promotion == Some(piece.Queen)
}

pub fn parse_with_check_suffix_test() {
  let pos = position.initial()
  let assert Ok(m) = san.parse("Nf3", pos)
  assert m.to == square.f3
}

pub fn parse_file_disambiguation_test() {
  let pos = parse_fen("4k3/8/8/8/8/8/3K4/R6R w - - 0 1")
  let assert Ok(m) = san.parse("Rad1", pos)
  assert m.from == square.a1
  assert m.to == square.d1
}

pub fn parse_rank_disambiguation_test() {
  let pos = parse_fen("4k3/4R3/8/8/8/8/8/4RK2 w - - 0 1")
  let assert Ok(m) = san.parse("R1e4", pos)
  assert m.from == square.e1
  assert m.to == square.e4
}

pub fn parse_no_matching_move_test() {
  let pos = position.initial()
  let result = san.parse("Be4", pos)
  assert result == Error(san.NoMatchingMove("Be4"))
}

pub fn parse_en_passant_test() {
  let pos = parse_fen("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
  let assert Ok(m) = san.parse("exd6", pos)
  assert m.from == square.e5
  assert m.to == square.d6
  assert m.is_en_passant == True
}

// --- SAN formatting tests ---

pub fn format_pawn_push_test() {
  let pos = position.initial()
  let m = move.Move(from: square.e2, to: square.e4, promotion: None, is_castling: False, is_en_passant: False)
  assert san.to_string(m, pos) == "e4"
}

pub fn format_knight_move_test() {
  let pos = position.initial()
  let m = move.Move(from: square.g1, to: square.f3, promotion: None, is_castling: False, is_en_passant: False)
  assert san.to_string(m, pos) == "Nf3"
}

pub fn format_pawn_capture_test() {
  let pos = parse_fen("4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1")
  let m = move.Move(from: square.e4, to: square.d5, promotion: None, is_castling: False, is_en_passant: False)
  assert san.to_string(m, pos) == "exd5"
}

pub fn format_castling_kingside_test() {
  let pos = parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1")
  let m = move.Move(from: square.e1, to: square.g1, promotion: None, is_castling: True, is_en_passant: False)
  assert san.to_string(m, pos) == "O-O"
}

pub fn format_castling_queenside_test() {
  let pos = parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1")
  let m = move.Move(from: square.e1, to: square.c1, promotion: None, is_castling: True, is_en_passant: False)
  assert san.to_string(m, pos) == "O-O-O"
}

pub fn format_promotion_test() {
  let pos = parse_fen("8/4P3/1k6/8/8/8/8/K7 w - - 0 1")
  let m = move.Move(from: square.e7, to: square.e8, promotion: Some(piece.Queen), is_castling: False, is_en_passant: False)
  assert san.to_string(m, pos) == "e8=Q"
}

pub fn format_checkmate_test() {
  let pos = parse_fen("r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4")
  let m = move.Move(from: square.h5, to: square.f7, promotion: None, is_castling: False, is_en_passant: False)
  assert san.to_string(m, pos) == "Qxf7#"
}

pub fn format_check_test() {
  let pos = parse_fen("4k3/8/8/8/8/8/4R3/4K3 w - - 0 1")
  let m = move.Move(from: square.e2, to: square.e7, promotion: None, is_castling: False, is_en_passant: False)
  assert san.to_string(m, pos) == "Re7+"
}

// --- Roundtrip tests ---

pub fn roundtrip_opening_moves_test() {
  let pos = position.initial()
  let assert Ok(m) = san.parse("e4", pos)
  assert san.to_string(m, pos) == "e4"

  let assert Ok(m2) = san.parse("Nf3", pos)
  assert san.to_string(m2, pos) == "Nf3"
}
