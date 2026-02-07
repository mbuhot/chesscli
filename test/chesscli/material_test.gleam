import chesscli/chess/board
import chesscli/chess/material.{CapturedMaterial, MaterialSummary}
import chesscli/chess/piece.{Bishop, Knight, Pawn, Queen, Rook}
import chesscli/chess/square

// --- from_board tests ---

pub fn initial_board_no_captures_test() {
  let summary = material.from_board(board.initial())
  assert summary
    == MaterialSummary(
    white_captures: CapturedMaterial(pieces: [], total_value: 0),
    black_captures: CapturedMaterial(pieces: [], total_value: 0),
    advantage: 0,
  )
}

pub fn white_captures_black_pawn_test() {
  // Remove a black pawn from the board
  let b = board.remove(board.initial(), square.a7)
  let summary = material.from_board(b)
  assert summary.white_captures == CapturedMaterial(pieces: [Pawn], total_value: 1)
  assert summary.black_captures == CapturedMaterial(pieces: [], total_value: 0)
  assert summary.advantage == 1
}

pub fn black_captures_white_queen_test() {
  // Remove white queen from the board
  let b = board.remove(board.initial(), square.d1)
  let summary = material.from_board(b)
  assert summary.white_captures == CapturedMaterial(pieces: [], total_value: 0)
  assert summary.black_captures == CapturedMaterial(pieces: [Queen], total_value: 9)
  assert summary.advantage == -9
}

pub fn both_sides_capture_test() {
  // Remove a black rook and a white knight
  let b =
    board.initial()
    |> board.remove(square.a8)
    |> board.remove(square.b1)
  let summary = material.from_board(b)
  assert summary.white_captures == CapturedMaterial(pieces: [Rook], total_value: 5)
  assert summary.black_captures == CapturedMaterial(pieces: [Knight], total_value: 3)
  assert summary.advantage == 2
}

pub fn captures_sorted_by_value_ascending_test() {
  // Remove black queen, knight, and two pawns
  let b =
    board.initial()
    |> board.remove(square.d8)
    |> board.remove(square.b8)
    |> board.remove(square.a7)
    |> board.remove(square.b7)
  let summary = material.from_board(b)
  assert summary.white_captures
    == CapturedMaterial(
    pieces: [Pawn, Pawn, Knight, Queen],
    total_value: 14,
  )
}

pub fn multiple_piece_types_sorted_test() {
  // Remove black queen, rook, bishop, knight, pawn
  let b =
    board.initial()
    |> board.remove(square.d8)
    |> board.remove(square.a8)
    |> board.remove(square.c8)
    |> board.remove(square.b8)
    |> board.remove(square.e7)
  let summary = material.from_board(b)
  assert summary.white_captures
    == CapturedMaterial(
    pieces: [Pawn, Bishop, Knight, Rook, Queen],
    total_value: 21,
  )
}

// --- format_captures tests ---

pub fn format_captures_with_lead_test() {
  let captures = CapturedMaterial(pieces: [Pawn, Pawn], total_value: 2)
  assert material.format_captures(captures, 2) == "♟♟ +2"
}

pub fn format_captures_without_lead_test() {
  // Even though this side captured a knight, the advantage is 0 (equal trades)
  let captures = CapturedMaterial(pieces: [Knight], total_value: 3)
  assert material.format_captures(captures, 0) == "♞"
}

pub fn format_captures_opponent_leads_test() {
  // This side captured a pawn but the other side leads
  let captures = CapturedMaterial(pieces: [Pawn], total_value: 1)
  assert material.format_captures(captures, -4) == "♟"
}

pub fn format_captures_empty_test() {
  let captures = CapturedMaterial(pieces: [], total_value: 0)
  assert material.format_captures(captures, 0) == ""
}

pub fn format_captures_mixed_pieces_test() {
  let captures =
    CapturedMaterial(pieces: [Pawn, Rook, Queen], total_value: 15)
  assert material.format_captures(captures, 7) == "♟♜♛ +7"
}
