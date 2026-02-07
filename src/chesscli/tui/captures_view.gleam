//// Renders player names, captured pieces, and material advantage above and
//// below the board, one line per player.

import chesscli/chess/board.{type Board}
import chesscli/chess/material
import etch/command
import etch/terminal
import gleam/list
import gleam/option.{type Option, None, Some}

/// Renders player names and captured material for both sides. Top row shows
/// the opponent's info, bottom row shows the player's, flipped by perspective.
pub fn render(
  board: Board,
  from_white: Bool,
  top_row: Int,
  bottom_row: Int,
  col: Int,
  white_name: Option(String),
  black_name: Option(String),
) -> List(command.Command) {
  let summary = material.from_board(board)

  let #(top_name, top_captures, top_advantage, bottom_name, bottom_captures, bottom_advantage) =
    case from_white {
      True -> #(
        black_name,
        summary.black_captures,
        -summary.advantage,
        white_name,
        summary.white_captures,
        summary.advantage,
      )
      False -> #(
        white_name,
        summary.white_captures,
        summary.advantage,
        black_name,
        summary.black_captures,
        -summary.advantage,
      )
    }

  let top_text = material.format_captures(top_captures, top_advantage)
  let bottom_text = material.format_captures(bottom_captures, bottom_advantage)

  list.flatten([
    render_line(top_row, col, top_name, top_text),
    render_line(bottom_row, col, bottom_name, bottom_text),
  ])
}

fn render_line(
  row: Int,
  col: Int,
  name: Option(String),
  captures: String,
) -> List(command.Command) {
  let text = case name, captures {
    Some(n), "" -> n
    Some(n), c -> n <> "  " <> c
    None, c -> c
  }
  [
    command.MoveTo(col, row),
    command.Clear(terminal.UntilNewLine),
    command.Print(text),
  ]
}
