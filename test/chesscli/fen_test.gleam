import chesscli/chess/board
import chesscli/chess/color.{Black, White}
import chesscli/chess/fen
import chesscli/chess/piece.{ColoredPiece, King, Pawn, Rook}
import chesscli/chess/position.{CastlingRights}
import chesscli/chess/square.{A, E, H, R1, R3, R8, Square}
import gleam/option.{None, Some}

const starting_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

const after_e4_fen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"

pub fn parse_starting_position_active_color_test() {
  let assert Ok(pos) = fen.parse(starting_fen)
  assert pos.active_color == White
}

pub fn parse_starting_position_castling_test() {
  let assert Ok(pos) = fen.parse(starting_fen)
  assert pos.castling
    == CastlingRights(
      white_kingside: True,
      white_queenside: True,
      black_kingside: True,
      black_queenside: True,
    )
}

pub fn parse_starting_position_en_passant_test() {
  let assert Ok(pos) = fen.parse(starting_fen)
  assert pos.en_passant == None
}

pub fn parse_starting_position_clocks_test() {
  let assert Ok(pos) = fen.parse(starting_fen)
  assert pos.halfmove_clock == 0
  assert pos.fullmove_number == 1
}

pub fn parse_starting_position_pieces_test() {
  let assert Ok(pos) = fen.parse(starting_fen)
  assert board.get(pos.board, Square(A, R1))
    == Some(ColoredPiece(White, Rook))
  assert board.get(pos.board, Square(E, R1))
    == Some(ColoredPiece(White, King))
  assert board.get(pos.board, Square(E, R8))
    == Some(ColoredPiece(Black, King))
  assert board.get(pos.board, Square(H, R8))
    == Some(ColoredPiece(Black, Rook))
}

pub fn parse_after_e4_active_color_test() {
  let assert Ok(pos) = fen.parse(after_e4_fen)
  assert pos.active_color == Black
}

pub fn parse_after_e4_en_passant_test() {
  let assert Ok(pos) = fen.parse(after_e4_fen)
  assert pos.en_passant == Some(Square(E, R3))
}

pub fn parse_after_e4_e4_pawn_test() {
  let assert Ok(pos) = fen.parse(after_e4_fen)
  assert board.get(pos.board, Square(E, square.R4))
    == Some(ColoredPiece(White, Pawn))
  // e2 should be empty
  assert board.get(pos.board, Square(E, square.R2)) == None
}

pub fn to_string_starting_position_test() {
  let assert Ok(pos) = fen.parse(starting_fen)
  assert fen.to_string(pos) == starting_fen
}

pub fn to_string_after_e4_test() {
  let assert Ok(pos) = fen.parse(after_e4_fen)
  assert fen.to_string(pos) == after_e4_fen
}

pub fn roundtrip_starting_position_test() {
  let assert Ok(pos) = fen.parse(starting_fen)
  let result = fen.to_string(pos)
  assert result == starting_fen
}

pub fn roundtrip_after_e4_test() {
  let assert Ok(pos) = fen.parse(after_e4_fen)
  let result = fen.to_string(pos)
  assert result == after_e4_fen
}

pub fn parse_no_castling_test() {
  let fen_str = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1"
  let assert Ok(pos) = fen.parse(fen_str)
  assert pos.castling
    == CastlingRights(
      white_kingside: False,
      white_queenside: False,
      black_kingside: False,
      black_queenside: False,
    )
}

pub fn parse_partial_castling_test() {
  let fen_str = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w Kq - 0 1"
  let assert Ok(pos) = fen.parse(fen_str)
  assert pos.castling
    == CastlingRights(
      white_kingside: True,
      white_queenside: False,
      black_kingside: False,
      black_queenside: True,
    )
}

pub fn roundtrip_no_castling_test() {
  let fen_str = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1"
  let assert Ok(pos) = fen.parse(fen_str)
  assert fen.to_string(pos) == fen_str
}

pub fn roundtrip_partial_castling_test() {
  let fen_str = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w Kq - 0 1"
  let assert Ok(pos) = fen.parse(fen_str)
  assert fen.to_string(pos) == fen_str
}

pub fn parse_invalid_too_few_fields_test() {
  assert fen.parse("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w")
    == Error(fen.InvalidBoard("expected 6 fields"))
}

pub fn parse_invalid_active_color_test() {
  assert fen.parse(
    "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR x KQkq - 0 1",
  )
    == Error(fen.InvalidActiveColor("x"))
}

pub fn parse_complex_position_test() {
  // Position after several moves with mixed pieces
  let fen_str = "r1bqkb1r/pppppppp/2n2n2/8/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3"
  let assert Ok(pos) = fen.parse(fen_str)
  assert pos.halfmove_clock == 2
  assert pos.fullmove_number == 3
  assert fen.to_string(pos) == fen_str
}
