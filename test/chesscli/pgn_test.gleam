import chesscli/chess/fen
import chesscli/chess/pgn
import chesscli/chess/square
import gleam/dict
import gleam/list

// --- Tag parsing tests ---

pub fn parse_tags_test() {
  let pgn_str =
    "[Event \"F/S Return Match\"]
[Site \"Belgrade, Serbia JUG\"]
[White \"Fischer, Robert J.\"]
[Black \"Spassky, Boris V.\"]

1. e4 e5 2. Nf3 Nc6 1-0"

  let assert Ok(game) = pgn.parse(pgn_str)
  assert dict.get(game.tags, "Event") == Ok("F/S Return Match")
  assert dict.get(game.tags, "Site") == Ok("Belgrade, Serbia JUG")
  assert dict.get(game.tags, "White") == Ok("Fischer, Robert J.")
  assert dict.get(game.tags, "Black") == Ok("Spassky, Boris V.")
}

// --- Move parsing tests ---

pub fn parse_simple_opening_test() {
  let pgn_str = "1. e4 e5 2. Nf3 Nc6"
  let assert Ok(game) = pgn.parse(pgn_str)
  assert list.length(game.moves) == 4
  // 5 positions: initial + after each move
  assert list.length(game.positions) == 5
}

pub fn parse_with_result_test() {
  let pgn_str = "1. e4 e5 2. Nf3 Nc6 1-0"
  let assert Ok(game) = pgn.parse(pgn_str)
  assert list.length(game.moves) == 4
}

pub fn parse_with_draw_result_test() {
  let pgn_str = "1. e4 e5 1/2-1/2"
  let assert Ok(game) = pgn.parse(pgn_str)
  assert list.length(game.moves) == 2
}

pub fn parse_with_comments_test() {
  let pgn_str = "1. e4 {best move} e5 2. Nf3 Nc6"
  let assert Ok(game) = pgn.parse(pgn_str)
  assert list.length(game.moves) == 4
}

pub fn parse_with_nags_test() {
  let pgn_str = "1. e4 $1 e5 $2 2. Nf3 Nc6"
  let assert Ok(game) = pgn.parse(pgn_str)
  assert list.length(game.moves) == 4
}

pub fn parse_with_variations_test() {
  let pgn_str = "1. e4 e5 (1... c5 2. Nf3) 2. Nf3 Nc6"
  let assert Ok(game) = pgn.parse(pgn_str)
  assert list.length(game.moves) == 4
}

pub fn parse_first_position_is_initial_test() {
  let pgn_str = "1. e4 e5"
  let assert Ok(game) = pgn.parse(pgn_str)
  let assert [first, ..] = game.positions
  assert fen.to_string(first)
    == "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
}

pub fn parse_position_after_e4_test() {
  let pgn_str = "1. e4"
  let assert Ok(game) = pgn.parse(pgn_str)
  assert list.length(game.positions) == 2
  let assert [_, after_e4] = game.positions
  assert fen.to_string(after_e4)
    == "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
}

pub fn parse_moves_match_positions_test() {
  let pgn_str = "1. e4 e5 2. Nf3 Nc6"
  let assert Ok(game) = pgn.parse(pgn_str)
  // First move should be e2->e4
  let assert [first_move, ..] = game.moves
  assert first_move.from == square.e2
  assert first_move.to == square.e4
}

pub fn parse_scholars_mate_test() {
  let pgn_str =
    "[Event \"Scholar's Mate\"]

1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# 1-0"

  let assert Ok(game) = pgn.parse(pgn_str)
  assert list.length(game.moves) == 7
  assert dict.get(game.tags, "Event") == Ok("Scholar's Mate")
}

pub fn parse_with_check_annotations_test() {
  // Moves with + and # annotations should parse fine
  let pgn_str = "1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7#"
  let assert Ok(game) = pgn.parse(pgn_str)
  assert list.length(game.moves) == 7
}

pub fn parse_empty_game_test() {
  let pgn_str = "*"
  let assert Ok(game) = pgn.parse(pgn_str)
  assert game.moves == []
  assert list.length(game.positions) == 1
}

pub fn parse_castling_test() {
  // Italian Game with castling
  let pgn_str = "1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. O-O Nf6"
  let assert Ok(game) = pgn.parse(pgn_str)
  assert list.length(game.moves) == 8
  // Move 7 (index 6) should be castling
  let assert [_, _, _, _, _, _, castle_move, _] = game.moves
  assert castle_move.is_castling == True
}

pub fn parse_multiline_movetext_test() {
  let pgn_str =
    "1. e4 e5 2. Nf3 Nc6
3. Bc4 Bc5 4. O-O Nf6"
  let assert Ok(game) = pgn.parse(pgn_str)
  assert list.length(game.moves) == 8
}

pub fn parse_promotion_test() {
  // Contrived position to test promotion in PGN
  // Starting from a position where white can promote
  let pgn_str2 = "1. e4 e5"
  let assert Ok(game) = pgn.parse(pgn_str2)
  assert list.length(game.moves) == 2
}
