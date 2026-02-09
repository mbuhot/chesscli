//// Horizontal eval bar rendered below the board showing white/black advantage.
//// Uses a sigmoid mapping to convert score to a visual fill ratio.

import chesscli/engine/uci.{type Score, Centipawns, Mate}
import etch/command
import etch/style
import gleam/float
import gleam/int
import gleam/list
import gleam/string

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

/// Render a horizontal eval bar as etch commands.
/// White fills from the left, dark from the right. Score label centered.
pub fn render(
  score: Score,
  start_col: Int,
  row: Int,
  width: Int,
) -> List(command.Command) {
  let ratio = score_to_white_ratio(score)
  let white_cols = float.round(ratio *. int.to_float(width))
  let white_cols = int.clamp(white_cols, 0, width)
  let label = pad_center(uci.format_score(score), width)

  // Render each column with the appropriate background color
  list.range(0, width - 1)
  |> list.flat_map(fn(i) {
    let col = start_col + i
    let is_white = i < white_cols
    let bg = case is_white {
      True -> white_bg
      False -> dark_bg
    }
    let fg = case is_white {
      True -> label_on_white_fg
      False -> label_on_dark_fg
    }
    let ch = string.slice(label, i, 1)
    [
      command.MoveTo(col, row),
      command.SetBackgroundColor(bg),
      command.SetForegroundColor(fg),
      command.Print(ch),
      command.ResetStyle,
    ]
  })
}

fn pad_center(text: String, width: Int) -> String {
  let len = string.length(text)
  case len >= width {
    True -> string.slice(text, 0, width)
    False -> {
      let pad = width - len
      let left = pad / 2
      let right = pad - left
      string_repeat(" ", left) <> text <> string_repeat(" ", right)
    }
  }
}

fn string_repeat(s: String, n: Int) -> String {
  case n <= 0 {
    True -> ""
    False -> s <> string_repeat(s, n - 1)
  }
}

@external(javascript, "./eval_bar_ffi.mjs", "float_exp")
fn float_exp(x: Float) -> Float
