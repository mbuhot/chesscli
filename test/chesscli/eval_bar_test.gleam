import chesscli/engine/uci.{Centipawns, Mate}
import chesscli/tui/eval_bar
import chesscli/tui/virtual_terminal
import gleam/float
import gleam/string

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
  let commands = eval_bar.render(Centipawns(0), 0, 0, 26)
  // Horizontal bar: 1 row, 26 chars wide
  let result = virtual_terminal.render_to_string(commands, 27, 1)
  // Even position: label "+0.00" centered in 26 chars
  assert result != ""
}

pub fn render_produces_commands_test() {
  let commands = eval_bar.render(Centipawns(200), 0, 0, 26)
  assert commands != []
}

pub fn render_full_score_label_test() {
  let commands = eval_bar.render(Centipawns(249), 0, 0, 26)
  let result = virtual_terminal.render_to_string(commands, 27, 1)
  // Full "+2.49" label should appear, not truncated
  assert string.contains(result, "+2.49")
}

pub fn render_mate_label_test() {
  let commands = eval_bar.render(Mate(3), 0, 0, 26)
  let result = virtual_terminal.render_to_string(commands, 27, 1)
  assert string.contains(result, "M3")
}
