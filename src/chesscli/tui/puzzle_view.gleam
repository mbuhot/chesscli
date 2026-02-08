//// Renders the puzzle info panel to the right of the board.
//// Shows puzzle number, classification badge, phase-dependent hints,
//// solution explanation, and session statistics.

import chesscli/chess/board.{type Board}
import chesscli/chess/color
import chesscli/engine/analysis.{Blunder, Miss, Mistake}
import chesscli/puzzle/puzzle.{
  type Puzzle, type PuzzlePhase, type TrainingSession, Correct, HintPiece,
  HintSquare, Incorrect, Revealed, Solving,
}
import etch/command
import etch/style
import etch/terminal
import gleam/int
import gleam/list
import gleam/option


/// Format the puzzle header line (e.g. "Puzzle 1/3").
pub fn format_header(session: TrainingSession) -> String {
  let n = session.current_index + 1
  let #(total, _, _) = puzzle.stats(session)
  "Puzzle " <> int.to_string(n) <> "/" <> int.to_string(total)
}

/// Format the classification badge text.
pub fn format_badge(p: Puzzle) -> String {
  case p.classification {
    Miss -> "Miss"
    Mistake -> "Mistake"
    Blunder -> "Blunder"
    _ -> ""
  }
}

/// Format the instruction line (e.g. "Find the best move for White").
pub fn format_instruction(p: Puzzle) -> String {
  "Find the best move for " <> color.to_string(p.player_color)
}

/// Format the solve progress line (e.g. "Solved: 1/3").
pub fn format_solve_progress(p: Puzzle) -> String {
  "Solved: " <> int.to_string(p.solve_count) <> "/3"
}

/// Format the phase-dependent content lines.
pub fn format_phase_content(
  phase: PuzzlePhase,
  p: Puzzle,
  board: Board,
  feedback: String,
) -> List(String) {
  case phase {
    Solving -> []
    HintPiece -> ["", puzzle.hint_piece(p, board)]
    HintSquare -> ["", puzzle.hint_square(p, board)]
    Correct -> [feedback]
    Incorrect -> [feedback]
    Revealed -> format_revealed(p, feedback)
  }
}

fn format_revealed(p: Puzzle, feedback: String) -> List(String) {
  let played_san = puzzle.format_uci_as_san(p.fen, p.played_uci)
  let played_line =
    "You played: " <> played_san <> " (eval " <> p.eval_after <> ")"
  let continuation_lines = puzzle.format_continuation(p, 30)
  list.flatten([[feedback, played_line], continuation_lines])
}

/// Format session completion statistics.
pub fn format_stats(session: TrainingSession) -> String {
  let #(total, solved, revealed) = puzzle.stats(session)
  int.to_string(solved)
  <> "/"
  <> int.to_string(total)
  <> " solved, "
  <> int.to_string(revealed)
  <> " revealed"
}

/// Render the puzzle panel at the given position.
pub fn render(
  session: TrainingSession,
  phase: PuzzlePhase,
  feedback: String,
  board: Board,
  start_col: Int,
  start_row: Int,
  max_height: Int,
) -> List(command.Command) {
  let assert option.Some(p) = puzzle.current_puzzle(session)
  let clear = command.Clear(terminal.UntilNewLine)

  let header = format_header(session)
  let badge = format_badge(p)
  let instruction = format_instruction(p)
  let content = format_phase_content(phase, p, board, feedback)

  let badge_cmds = render_badge(badge, p)

  let lines = list.flatten([
    // Row 0: header + badge
    [
      [command.MoveTo(start_col, start_row), command.ResetStyle],
      [command.SetAttributes([style.Bold]), command.Print(header <> "  ")],
      badge_cmds,
      [command.ResetStyle, clear],
    ],
    // Row 1: instruction
    [
      [command.MoveTo(start_col, start_row + 1), command.ResetStyle],
      [command.Print(instruction), clear],
    ],
    // Row 2: solve progress
    [
      [command.MoveTo(start_col, start_row + 2), command.ResetStyle],
      [command.Print(format_solve_progress(p)), clear],
    ],
    // Row 3+: phase content
    render_content_lines(content, start_col, start_row + 3, phase),
  ])

  // Clear remaining rows
  let used = 3 + list.length(content)
  let clear_cmds = clear_remaining(start_col, start_row + used, max_height - used)

  list.flatten([list.flatten(lines), clear_cmds])
}

fn render_badge(badge: String, p: Puzzle) -> List(command.Command) {
  case badge {
    "" -> []
    _ -> {
      let badge_color = case p.classification {
        Miss -> style.Rgb(0, 160, 200)
        Mistake -> style.Rgb(220, 120, 0)
        Blunder -> style.Rgb(220, 50, 50)
        _ -> style.Rgb(200, 200, 200)
      }
      [
        command.SetForegroundColor(badge_color),
        command.SetAttributes([style.Bold]),
        command.Print(badge),
        command.ResetStyle,
      ]
    }
  }
}

fn render_content_lines(
  lines: List(String),
  start_col: Int,
  start_row: Int,
  phase: PuzzlePhase,
) -> List(List(command.Command)) {
  list.index_map(lines, fn(line, i) {
    let color_cmds = case phase, i {
      Correct, 0 -> [command.SetForegroundColor(style.Rgb(0, 180, 0))]
      Incorrect, 0 -> [command.SetForegroundColor(style.Rgb(220, 180, 0))]
      Revealed, 0 -> [command.SetForegroundColor(style.Rgb(80, 140, 220))]
      HintPiece, _ -> [command.SetForegroundColor(style.Rgb(0, 160, 200))]
      HintSquare, _ -> [command.SetForegroundColor(style.Rgb(0, 160, 200))]
      _, _ -> []
    }
    list.flatten([
      [command.MoveTo(start_col, start_row + i), command.ResetStyle],
      color_cmds,
      [command.Print(line), command.ResetStyle],
      [command.Clear(terminal.UntilNewLine)],
    ])
  })
}


fn clear_remaining(
  start_col: Int,
  start_row: Int,
  count: Int,
) -> List(command.Command) {
  case count > 0 {
    True ->
      list.range(0, count - 1)
      |> list.flat_map(fn(i) {
        [
          command.MoveTo(start_col, start_row + i),
          command.ResetStyle,
          command.Clear(terminal.UntilNewLine),
        ]
      })
    False -> []
  }
}
