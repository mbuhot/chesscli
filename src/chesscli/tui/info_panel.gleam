//// Renders the move list and game tags panel to the right of the board.
//// Shows move numbers, SAN notation, and highlights the current position.

import chesscli/chess/game.{type Game}
import chesscli/chess/san
import chesscli/engine/analysis.{
  type GameAnalysis, type MoveClassification, Best, Blunder, Excellent, Good,
  Inaccuracy, Miss, Mistake,
}
import etch/command
import etch/style
import etch/terminal
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string

/// A formatted entry in the move list: the display text, whether it's
/// the move at the current cursor position, and optional quality classification.
pub type MoveEntry {
  MoveEntry(
    prefix: String,
    text: String,
    is_current: Bool,
    is_analyzing: Bool,
    classification: Option(MoveClassification),
  )
}

/// Format the game's moves as a list of entries with current-move highlighting.
/// When analysis is provided, each entry includes a move classification.
/// When deep_analysis_index is set, the move at that position is marked.
pub fn format_move_list(
  game: Game,
  analysis: Option(GameAnalysis),
  deep_analysis_index: Option(Int),
) -> List(MoveEntry) {
  let moves = game.moves
  let positions = game.positions
  let cursor = game.current_index
  let total = list.length(moves)
  let max_num = { total - 1 } / 2 + 1
  let num_width = string.length(int.to_string(max_num))

  list.index_map(moves, fn(m, i) {
    let assert Ok(pos) = list_at(positions, i)
    let san_text = san.to_string(m, pos)
    let is_current = i + 1 == cursor
    let move_number = i / 2 + 1
    let is_white_move = i % 2 == 0
    let is_analyzing = deep_analysis_index == option.Some(i)

    let prefix = case is_white_move {
      True -> {
        let num_str = int.to_string(move_number)
        let pad = string.repeat(" ", num_width - string.length(num_str))
        pad <> num_str <> ". "
      }
      False -> ""
    }
    let classification = get_classification(analysis, i)
    MoveEntry(
      prefix: prefix,
      text: san_text,
      is_current: is_current,
      is_analyzing: is_analyzing,
      classification: classification,
    )
  })
}

fn get_classification(
  analysis: Option(GameAnalysis),
  move_index: Int,
) -> Option(MoveClassification) {
  case analysis {
    option.None -> option.None
    option.Some(ga) ->
      list.find(ga.move_analyses, fn(ma) { ma.move_index == move_index })
      |> option.from_result
      |> option.map(fn(ma) { ma.classification })
  }
}

/// A paired line of white and black moves with individual current-move flags
/// and optional quality classifications.
pub type MoveLine {
  MoveLine(
    prefix: String,
    white_text: String,
    white_current: Bool,
    white_analyzing: Bool,
    white_classification: Option(MoveClassification),
    black_text: String,
    black_current: Bool,
    black_analyzing: Bool,
    black_classification: Option(MoveClassification),
  )
}

/// Format move list as paired lines with per-move current flags.
pub fn format_move_lines(
  game: Game,
  analysis: Option(GameAnalysis),
  deep_analysis_index: Option(Int),
) -> List(MoveLine) {
  let entries = format_move_list(game, analysis, deep_analysis_index)
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
        MoveLine(
          white.prefix,
          white.text,
          white.is_current,
          white.is_analyzing,
          white.classification,
          "",
          False,
          False,
          option.None,
        ),
        ..acc
      ])
    }
    [white, black, ..rest] -> {
      let line =
        MoveLine(
          white.prefix,
          white.text,
          white.is_current,
          white.is_analyzing,
          white.classification,
          black.text,
          black.is_current,
          black.is_analyzing,
          black.classification,
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
  analysis: Option(GameAnalysis),
  deep_analysis_index: Option(Int),
) -> List(command.Command) {
  render_moves(game, start_col, start_row, max_height, analysis, deep_analysis_index)
}

fn render_moves(
  game: Game,
  start_col: Int,
  start_row: Int,
  max_lines: Int,
  analysis: Option(GameAnalysis),
  deep_analysis_index: Option(Int),
) -> List(command.Command) {
  let lines = format_move_lines(game, analysis, deep_analysis_index)
  let visible = scroll_window(lines, max_lines)
  list.index_map(visible, fn(line, i) {
    let is_current = line.white_current || line.black_current
    let prefix = case is_current {
      True -> ">"
      False -> " "
    }
    let white_width = string.length(line.prefix) + string.length(line.white_text)
    let #(white_pad, mid_fish) = case line.white_analyzing {
      True -> #(string.repeat(" ", int.max(0, 10 - white_width - 2)), "\u{1F41F}")
      False -> #(string.repeat(" ", 10 - white_width), "")
    }
    let end_fish = case line.black_analyzing {
      True -> "\u{1F41F}"
      False -> ""
    }
    list.flatten([
      [command.MoveTo(start_col, start_row + i), command.ResetStyle],
      [command.Print(prefix <> line.prefix)],
      render_half(line.white_text, line.white_current, line.white_classification),
      [command.Print(white_pad <> mid_fish)],
      render_half(line.black_text, line.black_current, line.black_classification),
      [command.Print(end_fish)],
      [command.ResetStyle, command.Clear(terminal.UntilNewLine)],
    ])
  })
  |> list.flatten
}

fn render_half(
  text: String,
  is_current: Bool,
  classification: Option(MoveClassification),
) -> List(command.Command) {
  let color_cmds = case classification {
    option.Some(Best) | option.Some(Excellent) -> [
      command.SetForegroundColor(style.Rgb(0, 180, 0)),
    ]
    option.Some(Good) -> []
    option.Some(Miss) -> [
      command.SetForegroundColor(style.Rgb(0, 160, 200)),
    ]
    option.Some(Inaccuracy) -> [
      command.SetForegroundColor(style.Rgb(200, 180, 0)),
    ]
    option.Some(Mistake) -> [
      command.SetForegroundColor(style.Rgb(220, 120, 0)),
    ]
    option.Some(Blunder) -> [
      command.SetForegroundColor(style.Rgb(220, 50, 50)),
    ]
    option.None -> []
  }
  let style_cmds = case is_current {
    True -> [command.SetAttributes([style.Bold, style.Underline])]
    False -> []
  }
  list.flatten([
    color_cmds,
    style_cmds,
    [command.Print(text)],
    [command.ResetStyle],
  ])
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
