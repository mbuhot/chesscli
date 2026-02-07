import chesscli/chess/fen
import chesscli/chess/game
import chesscli/chess/move.{Move}
import chesscli/chess/pgn
import chesscli/chess/square
import gleam/dict
import gleam/list
import gleam/option.{None}

// --- from_pgn tests ---

pub fn from_pgn_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3 Nc6")
  let g = game.from_pgn(pgn_game)
  assert g.current_index == 0
  assert list.length(g.moves) == 4
  assert list.length(g.positions) == 5
}

pub fn from_pgn_preserves_tags_test() {
  let assert Ok(pgn_game) =
    pgn.parse(
      "[White \"Fischer\"]
[Black \"Spassky\"]

1. e4 e5",
    )
  let g = game.from_pgn(pgn_game)
  assert dict.get(g.tags, "White") == Ok("Fischer")
  assert dict.get(g.tags, "Black") == Ok("Spassky")
}

// --- new game tests ---

pub fn new_game_test() {
  let g = game.new()
  assert g.current_index == 0
  assert g.moves == []
  assert list.length(g.positions) == 1
}

// --- current_position tests ---

pub fn current_position_initial_test() {
  let g = game.new()
  let pos = game.current_position(g)
  assert fen.to_string(pos)
    == "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
}

pub fn current_position_after_forward_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let g = game.from_pgn(pgn_game)
  let assert Ok(g) = game.forward(g)
  let pos = game.current_position(g)
  assert fen.to_string(pos)
    == "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
}

// --- forward/backward tests ---

pub fn forward_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let g = game.from_pgn(pgn_game)
  let assert Ok(g) = game.forward(g)
  assert g.current_index == 1
  let assert Ok(g) = game.forward(g)
  assert g.current_index == 2
}

pub fn forward_at_end_fails_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4")
  let g = game.from_pgn(pgn_game)
  let assert Ok(g) = game.forward(g)
  assert game.forward(g) == Error(Nil)
}

pub fn backward_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let g = game.from_pgn(pgn_game)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.backward(g)
  assert g.current_index == 1
}

pub fn backward_at_start_fails_test() {
  let g = game.new()
  assert game.backward(g) == Error(Nil)
}

// --- goto tests ---

pub fn goto_start_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3 Nc6")
  let g = game.from_pgn(pgn_game)
  let g = game.goto_end(g)
  assert g.current_index == 4
  let g = game.goto_start(g)
  assert g.current_index == 0
}

pub fn goto_end_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3 Nc6")
  let g = game.from_pgn(pgn_game)
  let g = game.goto_end(g)
  assert g.current_index == 4
}

// --- apply_move tests ---

pub fn apply_move_test() {
  let g = game.new()
  let m = Move(from: square.e2, to: square.e4, promotion: None, is_castling: False, is_en_passant: False)
  let assert Ok(g) = game.apply_move(g, m)
  assert g.current_index == 1
  assert list.length(g.moves) == 1
  let pos = game.current_position(g)
  assert fen.to_string(pos)
    == "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
}

pub fn apply_illegal_move_fails_test() {
  let g = game.new()
  // Try to move e2 to e5 (illegal - too far)
  let m = Move(from: square.e2, to: square.e5, promotion: None, is_castling: False, is_en_passant: False)
  assert game.apply_move(g, m) == Error(game.IllegalMove)
}

pub fn apply_move_truncates_future_test() {
  // Load a game, go back, then play a different move
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3 Nc6")
  let g = game.from_pgn(pgn_game)
  let assert Ok(g) = game.forward(g)
  // Now at index 1 (after e4). Apply d5 instead of e5
  let m = Move(from: square.d7, to: square.d5, promotion: None, is_castling: False, is_en_passant: False)
  let assert Ok(g) = game.apply_move(g, m)
  // Should have truncated: 2 moves now, not 4
  assert list.length(g.moves) == 2
  assert g.current_index == 2
}
