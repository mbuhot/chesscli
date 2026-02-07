import chesscli/engine/uci.{Centipawns, Mate}
import chesscli/tui/eval_bar
import chesscli/tui/virtual_terminal
import gleam/float

fn approx_eq(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <. 0.01
}

// --- score_to_white_ratio ---

pub fn ratio_even_test() {
  assert approx_eq(eval_bar.score_to_white_ratio(Centipawns(0)), 0.5)
}

pub fn ratio_white_winning_test() {
  let ratio = eval_bar.score_to_white_ratio(Centipawns(300))
  assert ratio >. 0.5
  assert ratio <. 1.0
}

pub fn ratio_black_winning_test() {
  let ratio = eval_bar.score_to_white_ratio(Centipawns(-300))
  assert ratio <. 0.5
  assert ratio >. 0.0
}

pub fn ratio_white_mate_test() {
  let ratio = eval_bar.score_to_white_ratio(Mate(3))
  assert ratio >. 0.95
}

pub fn ratio_black_mate_test() {
  let ratio = eval_bar.score_to_white_ratio(Mate(-2))
  assert ratio <. 0.05
}

// --- render snapshot ---

pub fn render_even_position_test() {
  let commands = eval_bar.render(Centipawns(0), 0, 0, 8)
  // Bar should have 8 rows at column 0, width 2
  let result = virtual_terminal.render_to_string(commands, 3, 8)
  // Even position: 4 dark rows on top, 4 white rows on bottom
  // Each row has a 2-char block
  assert result != ""
}

pub fn render_produces_commands_test() {
  let commands = eval_bar.render(Centipawns(200), 0, 0, 8)
  // Should produce non-empty command list
  assert commands != []
}
