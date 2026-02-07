import chesscli/chess/color.{Black, White}
import chesscli/chess/fen
import chesscli/chess/move
import chesscli/chess/move_gen
import chesscli/chess/position.{type Position}
import chesscli/chess/square
import gleam/list

// --- Helper functions ---

fn has_move(pos: Position, from: square.Square, to: square.Square) -> Bool {
  move_gen.legal_moves(pos)
  |> list.any(fn(m) { m.from == from && m.to == to })
}

fn parse_fen(s: String) -> Position {
  let assert Ok(pos) = fen.parse(s)
  pos
}

// --- Pawn move tests ---

pub fn pawn_single_push_test() {
  let pos = parse_fen("4k3/8/8/8/8/8/4P3/4K3 w - - 0 1")
  assert has_move(pos, square.e2, square.e3) == True
}

pub fn pawn_double_push_test() {
  let pos = parse_fen("4k3/8/8/8/8/8/4P3/4K3 w - - 0 1")
  assert has_move(pos, square.e2, square.e4) == True
}

pub fn pawn_no_double_push_from_rank3_test() {
  let pos = parse_fen("4k3/8/8/8/8/4P3/8/4K3 w - - 0 1")
  assert has_move(pos, square.e3, square.e5) == False
}

pub fn pawn_blocked_test() {
  let pos = parse_fen("4k3/8/8/8/8/4p3/4P3/4K3 w - - 0 1")
  assert has_move(pos, square.e2, square.e3) == False
  assert has_move(pos, square.e2, square.e4) == False
}

pub fn pawn_capture_test() {
  let pos = parse_fen("4k3/8/8/8/8/3p4/4P3/4K3 w - - 0 1")
  assert has_move(pos, square.e2, square.d3) == True
}

pub fn pawn_no_capture_own_piece_test() {
  let pos = parse_fen("4k3/8/8/8/8/3P4/4P3/4K3 w - - 0 1")
  assert has_move(pos, square.e2, square.d3) == False
}

pub fn pawn_en_passant_test() {
  let pos = parse_fen("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
  assert has_move(pos, square.e5, square.d6) == True
}

pub fn pawn_promotion_test() {
  let pos = parse_fen("3k4/4P3/8/8/8/8/8/4K3 w - - 0 1")
  let moves = move_gen.legal_moves(pos)
  let promo_moves =
    list.filter(moves, fn(m) {
      m.from == square.e7 && m.to == square.e8
    })
  // Should have 4 promotion options: Q, R, B, N
  assert list.length(promo_moves) == 4
}

pub fn black_pawn_moves_test() {
  let pos = parse_fen("4k3/4p3/8/8/8/8/8/4K3 b - - 0 1")
  assert has_move(pos, square.e7, square.e6) == True
  assert has_move(pos, square.e7, square.e5) == True
}

// --- Knight move tests ---

pub fn knight_center_test() {
  let pos = parse_fen("4k3/8/8/8/4N3/8/8/4K3 w - - 0 1")
  let moves =
    move_gen.legal_moves(pos)
    |> list.filter(fn(m) { m.from == square.e4 })
  assert list.length(moves) == 8
}

pub fn knight_corner_test() {
  let pos = parse_fen("4k3/8/8/8/8/8/8/N3K3 w - - 0 1")
  let moves =
    move_gen.legal_moves(pos)
    |> list.filter(fn(m) { m.from == square.a1 })
  assert list.length(moves) == 2
}

pub fn knight_captures_enemy_test() {
  let pos = parse_fen("4k3/8/3p1p2/8/4N3/8/8/4K3 w - - 0 1")
  assert has_move(pos, square.e4, square.d6) == True
  assert has_move(pos, square.e4, square.f6) == True
}

// --- Bishop move tests ---

pub fn bishop_open_board_test() {
  let pos = parse_fen("4k3/8/8/8/4B3/8/8/4K3 w - - 0 1")
  let moves =
    move_gen.legal_moves(pos)
    |> list.filter(fn(m) { m.from == square.e4 })
  assert list.length(moves) == 13
}

pub fn bishop_blocked_by_own_piece_test() {
  let pos = parse_fen("4k3/8/8/3P4/4B3/8/8/4K3 w - - 0 1")
  assert has_move(pos, square.e4, square.d5) == False
}

pub fn bishop_captures_enemy_test() {
  let pos = parse_fen("4k3/8/8/3p4/4B3/8/8/4K3 w - - 0 1")
  assert has_move(pos, square.e4, square.d5) == True
  assert has_move(pos, square.e4, square.c6) == False
}

// --- Rook move tests ---

pub fn rook_open_file_test() {
  let pos = parse_fen("4k3/8/8/8/4R3/8/8/4K3 w - - 0 1")
  let moves =
    move_gen.legal_moves(pos)
    |> list.filter(fn(m) { m.from == square.e4 })
  assert list.length(moves) == 13
}

// --- Queen move tests ---

pub fn queen_combines_bishop_rook_test() {
  let pos = parse_fen("4k3/8/8/8/4Q3/8/8/4K3 w - - 0 1")
  let moves =
    move_gen.legal_moves(pos)
    |> list.filter(fn(m) { m.from == square.e4 })
  assert list.length(moves) == 26
}

// --- King move tests ---

pub fn king_normal_moves_test() {
  let pos = parse_fen("4k3/8/8/8/4K3/8/8/8 w - - 0 1")
  let moves =
    move_gen.legal_moves(pos)
    |> list.filter(fn(m) { m.from == square.e4 })
  assert list.length(moves) == 8
}

pub fn king_edge_test() {
  let pos = parse_fen("4k3/8/8/8/8/8/8/K7 w - - 0 1")
  let moves =
    move_gen.legal_moves(pos)
    |> list.filter(fn(m) { m.from == square.a1 })
  assert list.length(moves) == 3
}

// --- Castling tests ---

pub fn white_kingside_castling_test() {
  let pos = parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1")
  assert has_move(pos, square.e1, square.g1) == True
}

pub fn white_queenside_castling_test() {
  let pos = parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1")
  assert has_move(pos, square.e1, square.c1) == True
}

pub fn castling_blocked_by_piece_test() {
  let pos = parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/RN2K2R w KQkq - 0 1")
  assert has_move(pos, square.e1, square.c1) == False
}

pub fn castling_through_check_test() {
  let pos = parse_fen("5r2/8/8/8/8/8/PPPPP1PP/R3K2R w KQ - 0 1")
  assert has_move(pos, square.e1, square.g1) == False
}

pub fn castling_out_of_check_test() {
  let pos = parse_fen("4r3/8/8/8/8/8/PPPP1PPP/R3K2R w KQ - 0 1")
  assert has_move(pos, square.e1, square.g1) == False
  assert has_move(pos, square.e1, square.c1) == False
}

pub fn no_castling_rights_test() {
  let pos = parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w - - 0 1")
  assert has_move(pos, square.e1, square.g1) == False
  assert has_move(pos, square.e1, square.c1) == False
}

// --- Check detection tests ---

pub fn not_in_check_initial_test() {
  let pos = position.initial()
  assert move_gen.is_in_check(pos, White) == False
  assert move_gen.is_in_check(pos, Black) == False
}

pub fn king_in_check_by_rook_test() {
  let pos = parse_fen("4k3/8/8/8/4r3/8/8/4K3 w - - 0 1")
  assert move_gen.is_in_check(pos, White) == True
}

pub fn king_in_check_by_bishop_test() {
  let pos = parse_fen("4k3/8/8/8/8/8/3b4/4K3 w - - 0 1")
  assert move_gen.is_in_check(pos, White) == True
}

pub fn king_in_check_by_knight_test() {
  let pos = parse_fen("4k3/8/8/8/8/3n4/8/4K3 w - - 0 1")
  assert move_gen.is_in_check(pos, White) == True
}

pub fn king_in_check_by_pawn_test() {
  let pos = parse_fen("4k3/3P4/8/8/8/8/8/4K3 b - - 0 1")
  assert move_gen.is_in_check(pos, Black) == True
}

// --- Game status tests ---

pub fn checkmate_scholars_mate_test() {
  let pos = parse_fen("r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4")
  assert move_gen.game_status(pos) == move_gen.Checkmate
}

pub fn stalemate_test() {
  let pos = parse_fen("k7/8/KQ6/8/8/8/8/8 b - - 0 1")
  assert move_gen.game_status(pos) == move_gen.Stalemate
}

pub fn in_progress_initial_test() {
  let pos = position.initial()
  assert move_gen.game_status(pos) == move_gen.InProgress
}

// --- Perft tests (counting legal moves at depth) ---

fn perft(pos: Position, depth: Int) -> Int {
  case depth {
    0 -> 1
    _ -> {
      move_gen.legal_moves(pos)
      |> list.fold(0, fn(acc, m) {
        let new_pos = move.apply(pos, m)
        acc + perft(new_pos, depth - 1)
      })
    }
  }
}

pub fn perft_depth_1_test() {
  let pos = position.initial()
  assert perft(pos, 1) == 20
}

pub fn perft_depth_2_test() {
  let pos = position.initial()
  assert perft(pos, 2) == 400
}

pub fn perft_depth_3_test() {
  let pos = position.initial()
  assert perft(pos, 3) == 8902
}
