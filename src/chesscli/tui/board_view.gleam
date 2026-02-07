import chesscli/chess/board.{type Board}
import chesscli/chess/color.{Black, White}
import chesscli/chess/piece
import chesscli/chess/square.{Square}
import etch/command
import etch/style
import gleam/dict
import gleam/int
import gleam/list

/// Width of each square in characters
const square_width = 3

/// Chess.com green color scheme
const light_square_bg = style.Rgb(210, 211, 185)

const dark_square_bg = style.Rgb(119, 149, 86)

/// Piece foreground colors
const white_piece_fg = style.Rgb(255, 255, 255)

const black_piece_fg = style.Rgb(30, 30, 30)

/// Render the board as a list of etch commands.
/// `from_white` controls perspective: True = white at bottom (rank 1 at bottom).
pub fn render(board: Board, from_white: Bool) -> List(command.Command) {
  let ranks = case from_white {
    True -> [7, 6, 5, 4, 3, 2, 1, 0]
    False -> [0, 1, 2, 3, 4, 5, 6, 7]
  }
  let files = case from_white {
    True -> [0, 1, 2, 3, 4, 5, 6, 7]
    False -> [7, 6, 5, 4, 3, 2, 1, 0]
  }

  let top_row = 1
  let left_col = 3

  list.flatten([
    render_file_labels(files, top_row, left_col),
    render_top_border(top_row + 1, left_col - 1),
    render_ranks(board, ranks, files, top_row + 2, left_col),
    render_bottom_border(top_row + 2 + list.length(ranks), left_col - 1),
    [command.ResetStyle],
  ])
}

fn render_file_labels(
  files: List(Int),
  row: Int,
  left_col: Int,
) -> List(command.Command) {
  let labels =
    list.index_map(files, fn(file_idx, i) {
      let assert Ok(file) = square.file_from_int(file_idx)
      let label = file_to_label(file)
      let col = left_col + 2 + i * square_width
      [command.MoveTo(col, row), command.Print(label)]
    })
    |> list.flatten

  [command.MoveTo(left_col, row), command.Print("   "), ..labels]
}

fn render_top_border(row: Int, col: Int) -> List(command.Command) {
  let width = 2 + 8 * square_width + 1
  let border =
    "┌" <> string_repeat("─", width - 2) <> "┐"
  [command.MoveTo(col, row), command.Print(border)]
}

fn render_bottom_border(row: Int, col: Int) -> List(command.Command) {
  let width = 2 + 8 * square_width + 1
  let border =
    "└" <> string_repeat("─", width - 2) <> "┘"
  [command.MoveTo(col, row), command.Print(border)]
}

fn render_ranks(
  board: Board,
  ranks: List(Int),
  files: List(Int),
  start_row: Int,
  left_col: Int,
) -> List(command.Command) {
  list.index_map(ranks, fn(rank_idx, row_offset) {
    let assert Ok(rank) = square.rank_from_int(rank_idx)
    let rank_label = int.to_string(rank_idx + 1)
    let row = start_row + row_offset

    list.flatten([
      [
        command.MoveTo(left_col - 2, row),
        command.ResetStyle,
        command.Print(rank_label),
        command.MoveTo(left_col - 1, row),
        command.Print("│"),
      ],
      render_rank_squares(board, rank, rank_idx, files, row, left_col),
      [
        command.ResetStyle,
        command.Print(" │"),
      ],
    ])
  })
  |> list.flatten
}

fn render_rank_squares(
  board: Board,
  rank: square.Rank,
  rank_idx: Int,
  files: List(Int),
  row: Int,
  left_col: Int,
) -> List(command.Command) {
  list.index_map(files, fn(file_idx, i) {
    let assert Ok(file) = square.file_from_int(file_idx)
    let sq = Square(file, rank)
    let is_light = { file_idx + rank_idx } % 2 == 1
    let bg = case is_light {
      True -> light_square_bg
      False -> dark_square_bg
    }

    let col = left_col + i * square_width
    let content = case dict.get(board.pieces, sq) {
      Ok(colored_piece) -> {
        let fg = case colored_piece.color {
          White -> white_piece_fg
          Black -> black_piece_fg
        }
        let symbol = piece.to_unicode(colored_piece)
        [
          command.MoveTo(col, row),
          command.SetBackgroundColor(bg),
          command.SetForegroundColor(fg),
          command.Print(" " <> symbol <> " "),
        ]
      }
      Error(_) -> [
        command.MoveTo(col, row),
        command.SetBackgroundColor(bg),
        command.Print("   "),
      ]
    }
    content
  })
  |> list.flatten
}

fn file_to_label(file: square.File) -> String {
  case file {
    square.A -> "a"
    square.B -> "b"
    square.C -> "c"
    square.D -> "d"
    square.E -> "e"
    square.F -> "f"
    square.G -> "g"
    square.H -> "h"
  }
}

fn string_repeat(s: String, n: Int) -> String {
  case n <= 0 {
    True -> ""
    False -> s <> string_repeat(s, n - 1)
  }
}
