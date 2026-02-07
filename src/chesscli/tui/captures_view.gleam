//// Renders captured pieces and material advantage above and below the board,
//// one line per player.

import chesscli/chess/board.{type Board}
import chesscli/chess/material
import etch/command
import etch/terminal
import gleam/list

/// Renders captured material for both sides. Top row shows one player's
/// captures, bottom row shows the other, flipped based on perspective.
pub fn render(
  board: Board,
  from_white: Bool,
  top_row: Int,
  bottom_row: Int,
  col: Int,
) -> List(command.Command) {
  let summary = material.from_board(board)

  let #(top_captures, top_advantage, bottom_captures, bottom_advantage) =
    case from_white {
      True -> #(
        summary.black_captures,
        -summary.advantage,
        summary.white_captures,
        summary.advantage,
      )
      False -> #(
        summary.white_captures,
        summary.advantage,
        summary.black_captures,
        -summary.advantage,
      )
    }

  let top_text = material.format_captures(top_captures, top_advantage)
  let bottom_text = material.format_captures(bottom_captures, bottom_advantage)

  list.flatten([
    render_line(top_row, col, top_text),
    render_line(bottom_row, col, bottom_text),
  ])
}

fn render_line(row: Int, col: Int, text: String) -> List(command.Command) {
  case text {
    "" -> [
      command.MoveTo(col, row),
      command.Clear(terminal.UntilNewLine),
    ]
    _ -> [
      command.MoveTo(col, row),
      command.Clear(terminal.UntilNewLine),
      command.Print(text),
    ]
  }
}
