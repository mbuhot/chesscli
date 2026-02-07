import chesscli/chess/game
import chesscli/chess/pgn
import chesscli/tui/info_panel.{MoveEntry}
import etch/command
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
  assert entries == [MoveEntry(prefix: "1. ", text: "e4", is_current: True)]
}

pub fn format_move_list_two_moves_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let g = game.from_pgn(pgn_game)
  let g = game.goto_end(g)
  let entries = info_panel.format_move_list(g)
  assert list.length(entries) == 2
  let assert [white, black] = entries
  assert white.prefix == "1. "
  assert white.text == "e4"
  assert white.is_current == False
  assert black.prefix == ""
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
  assert first.prefix == "1. "
  assert first.text == "e4"
}

// --- format_move_lines ---

pub fn format_move_lines_pairs_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3 Nc6")
  let g = game.from_pgn(pgn_game)
  let g = game.goto_end(g)
  let lines = info_panel.format_move_lines(g)
  assert list.length(lines) == 2
  let assert [line1, line2] = lines
  assert line1.prefix == "1. "
  assert line1.white_text == "e4"
  assert line1.black_text == "e5"
  assert line2.prefix == "2. "
  assert line2.white_text == "Nf3"
  assert line2.black_text == "Nc6"
}

pub fn format_move_lines_odd_move_count_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3")
  let g = game.from_pgn(pgn_game)
  let g = game.goto_end(g)
  let lines = info_panel.format_move_lines(g)
  assert list.length(lines) == 2
  let assert [_, line2] = lines
  assert line2.prefix == "2. "
  assert line2.white_text == "Nf3"
  assert line2.black_text == ""
}

pub fn format_move_lines_current_line_highlighted_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5 2. Nf3 Nc6")
  let g = game.from_pgn(pgn_game)
  // Go to after move 3 (2. Nf3)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let assert Ok(g) = game.forward(g)
  let lines = info_panel.format_move_lines(g)
  let assert [line1, line2] = lines
  assert line1.white_current == False
  assert line1.black_current == False
  assert line2.white_current == True
  assert line2.black_current == False
}

// --- render ---

pub fn render_produces_commands_test() {
  let assert Ok(pgn_game) = pgn.parse("1. e4 e5")
  let g = game.from_pgn(pgn_game)
  let g = game.goto_end(g)
  let commands = info_panel.render(g, 32, 1, 10)
  assert commands != []
}

// --- scrolling with long games ---

pub fn render_long_game_limits_output_test() {
  // 10+ move game should produce commands fitting within max_height
  let assert Ok(pgn_game) =
    pgn.parse(
      "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7 11. Nbd2 Bb7 12. Bc2 Re8",
    )
  let g = game.from_pgn(pgn_game)
  let g = game.goto_end(g)
  // 24 moves = 12 lines of move pairs, but max_height 8 should limit to 8
  let commands = info_panel.render(g, 32, 1, 8)
  // Count MoveTo commands to verify we don't exceed 8 rows of moves
  let move_to_count =
    list.filter(commands, fn(cmd) {
      case cmd {
        command.MoveTo(_, _) -> True
        _ -> False
      }
    })
    |> list.length
  // Should have at most 8 MoveTo commands (one per visible line)
  assert move_to_count <= 8
}

