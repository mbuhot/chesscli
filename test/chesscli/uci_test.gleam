import chesscli/engine/uci.{type UciInfo, Centipawns, Mate, UciInfo}
import gleam/option

// --- format_position ---

pub fn format_position_test() {
  assert uci.format_position("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    == "position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
}

// --- format_go ---

pub fn format_go_depth_18_test() {
  assert uci.format_go(18) == "go depth 18"
}

pub fn format_go_depth_1_test() {
  assert uci.format_go(1) == "go depth 1"
}

// --- format_score ---

pub fn format_score_positive_centipawns_test() {
  assert uci.format_score(Centipawns(35)) == "+0.35"
}

pub fn format_score_negative_centipawns_test() {
  assert uci.format_score(Centipawns(-150)) == "-1.50"
}

pub fn format_score_zero_centipawns_test() {
  assert uci.format_score(Centipawns(0)) == "0.00"
}

pub fn format_score_mate_positive_test() {
  assert uci.format_score(Mate(3)) == "M3"
}

pub fn format_score_mate_negative_test() {
  assert uci.format_score(Mate(-2)) == "-M2"
}

// --- parse_info ---

pub fn parse_info_centipawns_test() {
  let assert Ok(info) =
    uci.parse_info(
      "info depth 18 score cp 35 nodes 1234567 pv e2e4 e7e5 g1f3",
    )
  assert info.depth == 18
  assert info.score == Centipawns(35)
  assert info.nodes == 1_234_567
  assert info.pv == ["e2e4", "e7e5", "g1f3"]
}

pub fn parse_info_mate_score_test() {
  let assert Ok(info) =
    uci.parse_info("info depth 20 score mate 3 nodes 500000 pv e1g1 e8g8")
  assert info.score == Mate(3)
  assert info.pv == ["e1g1", "e8g8"]
}

pub fn parse_info_negative_score_test() {
  let assert Ok(info) =
    uci.parse_info("info depth 15 score cp -120 nodes 800000 pv d7d5")
  assert info.score == Centipawns(-120)
  assert info.depth == 15
}

pub fn parse_info_missing_score_returns_error_test() {
  assert uci.parse_info("info depth 10 nodes 1000") == Error(Nil)
}

pub fn parse_info_non_info_line_returns_error_test() {
  assert uci.parse_info("bestmove e2e4") == Error(Nil)
}

// --- parse_bestmove ---

pub fn parse_bestmove_with_ponder_test() {
  let assert Ok(result) = uci.parse_bestmove("bestmove e2e4 ponder e7e5")
  assert result == #("e2e4", option.Some("e7e5"))
}

pub fn parse_bestmove_without_ponder_test() {
  let assert Ok(result) = uci.parse_bestmove("bestmove e2e4")
  assert result == #("e2e4", option.None)
}

pub fn parse_bestmove_non_matching_returns_error_test() {
  assert uci.parse_bestmove("info depth 18 score cp 35") == Error(Nil)
}

// --- negate_score ---

pub fn negate_score_positive_centipawns_test() {
  assert uci.negate_score(Centipawns(35)) == Centipawns(-35)
}

pub fn negate_score_negative_centipawns_test() {
  assert uci.negate_score(Centipawns(-120)) == Centipawns(120)
}

pub fn negate_score_zero_centipawns_test() {
  assert uci.negate_score(Centipawns(0)) == Centipawns(0)
}

pub fn negate_score_positive_mate_test() {
  assert uci.negate_score(Mate(3)) == Mate(-3)
}

pub fn negate_score_negative_mate_test() {
  assert uci.negate_score(Mate(-2)) == Mate(2)
}
