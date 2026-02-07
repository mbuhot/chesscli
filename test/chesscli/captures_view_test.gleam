import chesscli/chess/board
import chesscli/chess/square
import chesscli/tui/captures_view
import chesscli/tui/virtual_terminal
import gleam/option.{None}

pub fn initial_board_no_captures_test() {
  let commands = captures_view.render(board.initial(), True, 0, 12, 4, None, None)
  let result = virtual_terminal.render_to_string(commands, 40, 13)
  // Row 0 and row 12 should be empty (no captures)
  assert result
    == "\n\n\n\n\n\n\n\n\n\n\n\n"
}

pub fn white_captures_black_pawn_from_white_perspective_test() {
  // Remove a black pawn — white captured it
  let b = board.remove(board.initial(), square.a7)
  let commands = captures_view.render(b, True, 0, 12, 4, None, None)
  let result = virtual_terminal.render_to_string(commands, 40, 13)
  // Top row (0) = black's captures (empty), bottom row (12) = white's captures
  // Split into rows
  let rows = string_split(result, "\n")
  let assert Ok(top_row) = list_at(rows, 0)
  let assert Ok(bottom_row) = list_at(rows, 12)
  assert string_trim(top_row) == ""
  assert string_trim(bottom_row) == "♟ +1"
}

pub fn white_captures_from_black_perspective_test() {
  // Remove a black pawn — white captured it, viewed from black perspective
  let b = board.remove(board.initial(), square.a7)
  let commands = captures_view.render(b, False, 0, 12, 4, None, None)
  let result = virtual_terminal.render_to_string(commands, 40, 13)
  // From black perspective: top = white's captures, bottom = black's captures
  let rows = string_split(result, "\n")
  let assert Ok(top_row) = list_at(rows, 0)
  let assert Ok(bottom_row) = list_at(rows, 12)
  assert string_trim(top_row) == "♟ +1"
  assert string_trim(bottom_row) == ""
}

pub fn both_sides_capture_test() {
  // Remove black rook and white knight
  let b =
    board.initial()
    |> board.remove(square.a8)
    |> board.remove(square.b1)
  let commands = captures_view.render(b, True, 0, 12, 4, None, None)
  let result = virtual_terminal.render_to_string(commands, 40, 13)
  let rows = string_split(result, "\n")
  let assert Ok(top_row) = list_at(rows, 0)
  let assert Ok(bottom_row) = list_at(rows, 12)
  // Black captured white knight (advantage -2, no + shown)
  assert string_trim(top_row) == "♞"
  // White captured black rook (advantage +2)
  assert string_trim(bottom_row) == "♜ +2"
}

import gleam/list
import gleam/string

fn string_split(s: String, sep: String) -> List(String) {
  string.split(s, sep)
}

fn string_trim(s: String) -> String {
  string.trim(s)
}

fn list_at(lst: List(a), index: Int) -> Result(a, Nil) {
  case list.drop(lst, index) {
    [head, ..] -> Ok(head)
    [] -> Error(Nil)
  }
}
