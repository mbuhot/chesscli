import chesscli/engine/uci.{Centipawns, Mate}

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
