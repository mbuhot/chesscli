//// Vertical eval bar rendered left of the board showing white/black advantage.
//// Uses a sigmoid mapping to convert score to a visual fill ratio.

import chesscli/engine/uci.{type Score, Centipawns, Mate}
import etch/command
import etch/style
import gleam/float
import gleam/int
import gleam/list

/// Eval bar width in characters.
const bar_width = 2

/// White fill color.
const white_bg = style.Rgb(240, 240, 240)

/// Dark fill color.
const dark_bg = style.Rgb(50, 50, 50)

/// Score label foreground on white background.
const label_on_white_fg = style.Rgb(30, 30, 30)

/// Score label foreground on dark background.
const label_on_dark_fg = style.Rgb(220, 220, 220)

/// Map a score to a ratio [0.0, 1.0] where 0.5 is even, 1.0 is white winning.
/// Uses a sigmoid curve so large advantages asymptotically approach the extremes.
pub fn score_to_white_ratio(score: Score) -> Float {
  let pawns = case score {
    Centipawns(cp) -> int.to_float(cp) /. 100.0
    Mate(n) if n > 0 -> 10.0
    Mate(_) -> -10.0
  }
  // Sigmoid: 1 / (1 + e^(-0.5 * pawns))
  let exp = float_exp(float.negate(0.5) *. pawns)
  1.0 /. { 1.0 +. exp }
}

/// Render a vertical eval bar as etch commands.
/// White fill grows from the bottom; dark fill from the top.
pub fn render(
  score: Score,
  col: Int,
  start_row: Int,
  height: Int,
) -> List(command.Command) {
  let ratio = score_to_white_ratio(score)
  let white_rows = float.round(ratio *. int.to_float(height))
  let white_rows = int.clamp(white_rows, 0, height)
  let label = uci.format_score(score)

  // Label goes in the middle of the bar
  let label_row = start_row + height / 2

  list.range(0, height - 1)
  |> list.flat_map(fn(i) {
    let row = start_row + i
    // Rows are top-to-bottom: top rows are dark (black advantage), bottom rows are white
    let dark_rows = height - white_rows
    let is_white = i >= dark_rows
    let bg = case is_white {
      True -> white_bg
      False -> dark_bg
    }
    let fg = case is_white {
      True -> label_on_white_fg
      False -> label_on_dark_fg
    }
    let text = case row == label_row {
      True -> pad_center(label, bar_width)
      False -> string_repeat(" ", bar_width)
    }
    [
      command.MoveTo(col, row),
      command.SetBackgroundColor(bg),
      command.SetForegroundColor(fg),
      command.Print(text),
      command.ResetStyle,
    ]
  })
}

fn pad_center(text: String, width: Int) -> String {
  let len = string_length(text)
  case len >= width {
    True -> string_take(text, width)
    False -> {
      let pad = width - len
      let left = pad / 2
      let right = pad - left
      string_repeat(" ", left) <> text <> string_repeat(" ", right)
    }
  }
}

import gleam/string

fn string_length(s: String) -> Int {
  string.length(s)
}

fn string_take(s: String, n: Int) -> String {
  string.slice(s, 0, n)
}

fn string_repeat(s: String, n: Int) -> String {
  case n <= 0 {
    True -> ""
    False -> s <> string_repeat(s, n - 1)
  }
}

@external(javascript, "./eval_bar_ffi.mjs", "float_exp")
fn float_exp(x: Float) -> Float
