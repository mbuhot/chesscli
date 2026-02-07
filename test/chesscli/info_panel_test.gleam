import chesscli/chess/game
import chesscli/chess/pgn
import chesscli/tui/info_panel.{MoveEntry}
import gleam/list

// --- format_move_list ---

pub fn format_move_list_empty_game_test() {
  let g = game.new()
  let entries = info_panel.format_move_list(g)
  assert entries == []
}

pub fn format_move_list_one_move_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4")
  let g = game.from_pgn(pgn_game)
  let g = game.goto_end(g)
  let entries = info_panel.format_move_list(g)
  assert entries == [MoveEntry(text: "1. e4", is_current: True)]
}

pub fn format_move_list_two_moves_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let g = game.from_pgn(pgn_game)
  let g = game.goto_end(g)
  let entries = info_panel.format_move_list(g)
  assert list.length(entries) == 2
  let assert [white, black] = entries
  assert white.text == "1. e4"
  assert white.is_current == False
  assert black.text == "e5"
  assert black.is_current == True
}

pub fn format_move_list_cursor_at_start_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3 Nc6")
  let g = game.from_pgn(pgn_game)
  // Cursor at 0 = before any moves, no entry should be current
  let entries = info_panel.format_move_list(g)
  let any_current = list.any(entries, fn(e) { e.is_current })
  assert any_current == False
}

pub fn format_move_list_cursor_after_first_move_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3 Nc6")
  let g = game.from_pgn(pgn_game)
  let assert Ok(g) = game.forward(g)
  // Cursor = 1, so move at index 0 (e4) should be current
  let entries = info_panel.format_move_list(g)
  let assert [first, ..] = entries
  assert first.is_current == True
  assert first.text == "1. e4"
}

// --- format_move_lines ---

pub fn format_move_lines_pairs_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3 Nc6")
  let g = game.from_pgn(pgn_game)
  let g = game.goto_end(g)
  let lines = info_panel.format_move_lines(g)
  assert list.length(lines) == 2
  let assert [#(line1, _), #(line2, _)] = lines
  // Line 1 should contain "1. e4" and "e5"
  assert { line1 |> contains("1. e4") } == True
  assert { line1 |> contains("e5") } == True
  // Line 2 should contain "2. Nf3" and "Nc6"
  assert { line2 |> contains("2. Nf3") } == True
  assert { line2 |> contains("Nc6") } == True
}

pub fn format_move_lines_odd_move_count_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3")
  let g = game.from_pgn(pgn_game)
  let g = game.goto_end(g)
  let lines = info_panel.format_move_lines(g)
  assert list.length(lines) == 2
  let assert [_, #(line2, _)] = lines
  // Line 2 should contain "2. Nf3" but not a black move
  assert { line2 |> contains("2. Nf3") } == True
}

pub fn format_move_lines_current_line_highlighted_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3 Nc6")
  let g = game.from_pgn(pgn_game)
  // Go to after move 3 (2. Nf3)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let lines = info_panel.format_move_lines(g)
  let assert [#(_, line1_current), #(_, line2_current)] = lines
  assert line1_current == False
  assert line2_current == True
}

// --- render ---

pub fn render_produces_commands_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let g = game.from_pgn(pgn_game)
  let g = game.goto_end(g)
  let commands = info_panel.render(g, 32, 1)
  assert commands != []
}

import gleam/string

fn contains(haystack: String, needle: String) -> Bool {
  string.contains(haystack, needle)
}
