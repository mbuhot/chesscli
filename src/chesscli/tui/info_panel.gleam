//// Renders the move list and game tags panel to the right of the board.
//// Shows move numbers, SAN notation, and highlights the current position.

import chesscli/chess/game.{type Game}
import chesscli/chess/san
import etch/command
import etch/style
import etch/terminal
import gleam/dict
import gleam/int
import gleam/list
import gleam/string

/// A formatted entry in the move list: the display text and whether it's
/// the move at the current cursor position.
pub type MoveEntry {
  MoveEntry(text: String, is_current: Bool)
}

/// Format the game's moves as a list of entries with current-move highlighting.
/// Each entry is either a move number ("1."), a white move, or a black move.
pub fn format_move_list(game: Game) -> List(MoveEntry) {
  let moves = game.moves
  let positions = game.positions
  let cursor = game.current_index

  list.index_map(moves, fn(m, i) {
    let assert Ok(pos) = list_at(positions, i)
    let san_text = san.to_string(m, pos)
    let is_current = i + 1 == cursor
    let move_number = i / 2 + 1
    let is_white_move = i % 2 == 0

    case is_white_move {
      True -> {
        let prefix = int.to_string(move_number) <> ". "
        MoveEntry(text: prefix <> san_text, is_current: is_current)
      }
      False -> MoveEntry(text: san_text, is_current: is_current)
    }
  })
}

/// Format move list as paired lines: "1. e4  e5", "2. Nf3  Nc6", etc.
pub fn format_move_lines(game: Game) -> List(#(String, Bool)) {
  let entries = format_move_list(game)
  format_pairs(entries, [])
}

fn format_pairs(
  entries: List(MoveEntry),
  acc: List(#(String, Bool)),
) -> List(#(String, Bool)) {
  case entries {
    [] -> list.reverse(acc)
    [white] -> {
      let line = pad_right(white.text, 10)
      list.reverse([#(line, white.is_current), ..acc])
    }
    [white, black, ..rest] -> {
      let line = pad_right(white.text, 10) <> black.text
      let is_current = white.is_current || black.is_current
      format_pairs(rest, [#(line, is_current), ..acc])
    }
  }
}

/// Render the info panel at the given position.
pub fn render(
  game: Game,
  start_col: Int,
  start_row: Int,
) -> List(command.Command) {
  let tag_commands = render_tags(game, start_col, start_row)
  let tag_count = dict.size(game.tags)
  let move_start_row = case tag_count > 0 {
    True -> start_row + tag_count + 1
    False -> start_row
  }
  let move_commands = render_moves(game, start_col, move_start_row)
  list.flatten([tag_commands, move_commands])
}

fn render_tags(
  game: Game,
  start_col: Int,
  start_row: Int,
) -> List(command.Command) {
  let white_tag = dict.get(game.tags, "White")
  let black_tag = dict.get(game.tags, "Black")

  let tags = case white_tag, black_tag {
    Ok(w), Ok(b) -> [w, b]
    Ok(w), _ -> [w]
    _, Ok(b) -> [b]
    _, _ -> []
  }

  list.index_map(tags, fn(tag, i) {
    [
      command.MoveTo(start_col, start_row + i),
      command.ResetStyle,
      command.Print(tag),
      command.Clear(terminal.UntilNewLine),
    ]
  })
  |> list.flatten
}

fn render_moves(
  game: Game,
  start_col: Int,
  start_row: Int,
) -> List(command.Command) {
  let lines = format_move_lines(game)
  list.index_map(lines, fn(line, i) {
    let #(text, is_current) = line
    let prefix = case is_current {
      True -> ">"
      False -> " "
    }
    let style_commands = case is_current {
      True -> [command.SetAttributes([style.Bold])]
      False -> []
    }
    list.flatten([
      [command.MoveTo(start_col, start_row + i), command.ResetStyle],
      style_commands,
      [command.Print(prefix <> text), command.Clear(terminal.UntilNewLine)],
    ])
  })
  |> list.flatten
}

fn pad_right(s: String, width: Int) -> String {
  let len = string.length(s)
  case len >= width {
    True -> s
    False -> s <> string.repeat(" ", width - len)
  }
}

fn list_at(lst: List(a), index: Int) -> Result(a, Nil) {
  case lst, index {
    [], _ -> Error(Nil)
    [head, ..], 0 -> Ok(head)
    [_, ..tail], n if n > 0 -> list_at(tail, n - 1)
    _, _ -> Error(Nil)
  }
}
