//// Renders player names, captured pieces, and material advantage above and
//// below the board, one line per player.

import chesscli/chess/board.{type Board}
import chesscli/chess/color.{type Color, Black, White}
import chesscli/chess/material
import etch/command
import etch/style
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
  active_color: Option(Color),
) -> List(command.Command) {
  let summary = material.from_board(board)

  let #(top_name, top_captures, top_advantage, top_color, bottom_name, bottom_captures, bottom_advantage, bottom_color) =
    case from_white {
      True -> #(
        black_name,
        summary.black_captures,
        -summary.advantage,
        Black,
        white_name,
        summary.white_captures,
        summary.advantage,
        White,
      )
      False -> #(
        white_name,
        summary.white_captures,
        summary.advantage,
        White,
        black_name,
        summary.black_captures,
        -summary.advantage,
        Black,
      )
    }

  let top_text = material.format_captures(top_captures, top_advantage)
  let bottom_text = material.format_captures(bottom_captures, bottom_advantage)
  let top_active = active_color == Some(top_color)
  let bottom_active = active_color == Some(bottom_color)

  list.flatten([
    render_line(top_row, col, top_name, top_text, top_active),
    render_line(bottom_row, col, bottom_name, bottom_text, bottom_active),
  ])
}

/// Render just player names above and below the board, without captures.
pub fn render_names(
  from_white: Bool,
  top_row: Int,
  bottom_row: Int,
  col: Int,
  white_name: Option(String),
  black_name: Option(String),
  active_color: Option(Color),
) -> List(command.Command) {
  let #(top_name, top_color, bottom_name, bottom_color) = case from_white {
    True -> #(black_name, Black, white_name, White)
    False -> #(white_name, White, black_name, Black)
  }
  let top_active = active_color == Some(top_color)
  let bottom_active = active_color == Some(bottom_color)
  list.flatten([
    render_line(top_row, col, top_name, "", top_active),
    render_line(bottom_row, col, bottom_name, "", bottom_active),
  ])
}

fn render_line(
  row: Int,
  col: Int,
  name: Option(String),
  captures: String,
  active: Bool,
) -> List(command.Command) {
  let name_commands = case name {
    Some(n) if active -> [
      command.SetAttributes([style.Underline]),
      command.Print(n),
      command.ResetStyle,
    ]
    Some(n) -> [command.Print(n)]
    None -> []
  }
  let separator = case name, captures {
    Some(_), c if c != "" -> [command.Print("  ")]
    _, _ -> []
  }
  let captures_commands = case captures {
    "" -> []
    c -> [command.Print(c)]
  }
  list.flatten([
    [command.MoveTo(col, row), command.Clear(terminal.UntilNewLine)],
    name_commands,
    separator,
    captures_commands,
  ])
}
