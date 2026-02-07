//// Renders the move list and game tags panel to the right of the board.
//// Shows move numbers, SAN notation, and highlights the current position.

import chesscli/chess/game.{type Game}
import chesscli/chess/san
import etch/command
import etch/style
import etch/terminal
import gleam/int
import gleam/list
import gleam/string

/// A formatted entry in the move list: the display text and whether it's
/// the move at the current cursor position.
pub type MoveEntry {
  MoveEntry(prefix: String, text: String, is_current: Bool)
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

    let prefix = case is_white_move {
      True -> int.to_string(move_number) <> ". "
      False -> ""
    }
    MoveEntry(prefix: prefix, text: san_text, is_current: is_current)
  })
}

/// A paired line of white and black moves with individual current-move flags.
pub type MoveLine {
  MoveLine(
    prefix: String,
    white_text: String,
    white_current: Bool,
    black_text: String,
    black_current: Bool,
  )
}

/// Format move list as paired lines with per-move current flags.
pub fn format_move_lines(game: Game) -> List(MoveLine) {
  let entries = format_move_list(game)
  format_pairs(entries, [])
}

fn format_pairs(
  entries: List(MoveEntry),
  acc: List(MoveLine),
) -> List(MoveLine) {
  case entries {
    [] -> list.reverse(acc)
    [white] -> {
      list.reverse([
        MoveLine(white.prefix, white.text, white.is_current, "", False),
        ..acc
      ])
    }
    [white, black, ..rest] -> {
      let line =
        MoveLine(
          white.prefix,
          white.text,
          white.is_current,
          black.text,
          black.is_current,
        )
      format_pairs(rest, [line, ..acc])
    }
  }
}

/// Render the move list panel at the given position, scrolling to keep
/// the current move visible within max_height rows.
pub fn render(
  game: Game,
  start_col: Int,
  start_row: Int,
  max_height: Int,
) -> List(command.Command) {
  render_moves(game, start_col, start_row, max_height)
}

fn render_moves(
  game: Game,
  start_col: Int,
  start_row: Int,
  max_lines: Int,
) -> List(command.Command) {
  let lines = format_move_lines(game)
  let visible = scroll_window(lines, max_lines)
  list.index_map(visible, fn(line, i) {
    let is_current = line.white_current || line.black_current
    let prefix = case is_current {
      True -> ">"
      False -> " "
    }
    let white_width = string.length(line.prefix) + string.length(line.white_text)
    let white_pad = string.repeat(" ", 10 - white_width)
    list.flatten([
      [command.MoveTo(start_col, start_row + i), command.ResetStyle],
      [command.Print(prefix <> line.prefix)],
      render_half(line.white_text, line.white_current),
      [command.Print(white_pad)],
      render_half(line.black_text, line.black_current),
      [command.ResetStyle, command.Clear(terminal.UntilNewLine)],
    ])
  })
  |> list.flatten
}

fn render_half(text: String, is_current: Bool) -> List(command.Command) {
  case is_current {
    True -> [
      command.SetAttributes([style.Bold, style.Underline]),
      command.Print(text),
      command.ResetStyle,
    ]
    False -> [command.Print(text)]
  }
}

/// Scroll a list of move lines so the current move is visible.
fn scroll_window(
  lines: List(MoveLine),
  max_lines: Int,
) -> List(MoveLine) {
  let total = list.length(lines)
  case total <= max_lines {
    True -> lines
    False -> {
      let current_idx = find_current_index(lines, 0)
      let half = max_lines / 2
      let start = int.max(0, int.min(current_idx - half, total - max_lines))
      lines
      |> list.drop(start)
      |> list.take(max_lines)
    }
  }
}

fn find_current_index(lines: List(MoveLine), index: Int) -> Int {
  case lines {
    [] -> 0
    [line, ..rest] ->
      case line.white_current || line.black_current {
        True -> index
        False -> find_current_index(rest, index + 1)
      }
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
