//// Renders the chess board as terminal commands with colored squares,
//// unicode pieces, and optional highlights for last move and check.

import chesscli/chess/board.{type Board}
import chesscli/chess/color.{Black, White}
import chesscli/chess/piece
import chesscli/chess/square.{type Square, Square}
import etch/command
import etch/style
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

/// Width of each square in characters
const square_width = 3

/// Chess.com green color scheme
const light_square_bg = style.Rgb(210, 211, 185)

const dark_square_bg = style.Rgb(119, 149, 86)

/// Last move highlight colors
const light_last_move_bg = style.Rgb(245, 246, 130)

const dark_last_move_bg = style.Rgb(186, 202, 68)

/// Check highlight colors
const light_check_bg = style.Rgb(235, 160, 160)

const dark_check_bg = style.Rgb(200, 100, 100)

/// Piece foreground colors
const white_piece_fg = style.Rgb(255, 255, 255)

const black_piece_fg = style.Rgb(30, 30, 30)

/// Best move highlight colors (blue)
const light_best_move_bg = style.Rgb(100, 160, 240)

const dark_best_move_bg = style.Rgb(60, 120, 200)

/// Controls how the board is rendered: perspective, and which squares to highlight.
pub type RenderOptions {
  RenderOptions(
    from_white: Bool,
    last_move_from: Option(Square),
    last_move_to: Option(Square),
    check_square: Option(Square),
    best_move_from: Option(Square),
    best_move_to: Option(Square),
  )
}

/// Default options: white perspective, no highlights.
pub fn default_options() -> RenderOptions {
  RenderOptions(
    from_white: True,
    last_move_from: None,
    last_move_to: None,
    check_square: None,
    best_move_from: None,
    best_move_to: None,
  )
}

/// Render the board as a list of etch commands.
/// Layout: rank labels sit left of the border, file labels below.
/// Columns: "  │" + 8×3-char squares + "│" gives symmetric borders.
pub fn render(board: Board, options: RenderOptions) -> List(command.Command) {
  let ranks = case options.from_white {
    True -> [7, 6, 5, 4, 3, 2, 1, 0]
    False -> [0, 1, 2, 3, 4, 5, 6, 7]
  }
  let files = case options.from_white {
    True -> [0, 1, 2, 3, 4, 5, 6, 7]
    False -> [7, 6, 5, 4, 3, 2, 1, 0]
  }

  // Layout columns:
  //   col 1-2: rank label + space  (e.g. "8 ")
  //   col 3:   left border "│"
  //   col 4-27: 8 squares × 3 chars
  //   col 28:  right border "│"
  let top_row = 1
  let left_col = 4
  let border_col = left_col - 1
  let board_width = 8 * square_width
  let num_ranks = list.length(ranks)

  list.flatten([
    render_top_border(top_row, border_col, board_width),
    render_ranks(board, ranks, files, top_row + 1, left_col, options),
    render_bottom_border(top_row + 1 + num_ranks, border_col, board_width),
    render_file_labels(files, top_row + 2 + num_ranks, left_col),
    [command.ResetStyle],
  ])
}

fn render_file_labels(
  files: List(Int),
  row: Int,
  left_col: Int,
) -> List(command.Command) {
  list.index_map(files, fn(file_idx, i) {
    let assert Ok(file) = square.file_from_int(file_idx)
    let label = square.file_to_string(file)
    // Center the label in the 3-char square: offset by 1
    let col = left_col + 1 + i * square_width
    [command.MoveTo(col, row), command.Print(label)]
  })
  |> list.flatten
}

fn render_top_border(
  row: Int,
  col: Int,
  board_width: Int,
) -> List(command.Command) {
  let border = "┌" <> string_repeat("─", board_width) <> "┐"
  [command.MoveTo(col, row), command.Print(border)]
}

fn render_bottom_border(
  row: Int,
  col: Int,
  board_width: Int,
) -> List(command.Command) {
  let border = "└" <> string_repeat("─", board_width) <> "┘"
  [command.MoveTo(col, row), command.Print(border)]
}

fn render_ranks(
  board: Board,
  ranks: List(Int),
  files: List(Int),
  start_row: Int,
  left_col: Int,
  options: RenderOptions,
) -> List(command.Command) {
  list.index_map(ranks, fn(rank_idx, row_offset) {
    let assert Ok(rank) = square.rank_from_int(rank_idx)
    let rank_label = int.to_string(rank_idx + 1)
    let row = start_row + row_offset

    list.flatten([
      [
        command.MoveTo(left_col - 3, row),
        command.ResetStyle,
        command.Print(rank_label <> " │"),
      ],
      render_rank_squares(board, rank, rank_idx, files, row, left_col, options),
      [
        command.ResetStyle,
        command.Print("│"),
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
  options: RenderOptions,
) -> List(command.Command) {
  list.index_map(files, fn(file_idx, i) {
    let assert Ok(file) = square.file_from_int(file_idx)
    let sq = Square(file, rank)
    let is_light = { file_idx + rank_idx } % 2 == 1
    let bg = square_bg(sq, is_light, options)

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

/// Pick the background color for a square, applying highlight overrides.
/// Priority: check > best_move > last_move > normal.
fn square_bg(
  sq: Square,
  is_light: Bool,
  options: RenderOptions,
) -> style.Color {
  case options.check_square {
    Some(check_sq) if check_sq == sq ->
      case is_light {
        True -> light_check_bg
        False -> dark_check_bg
      }
    _ ->
      case options.best_move_from, options.best_move_to {
        Some(from), _ if from == sq ->
          case is_light {
            True -> light_best_move_bg
            False -> dark_best_move_bg
          }
        _, Some(to) if to == sq ->
          case is_light {
            True -> light_best_move_bg
            False -> dark_best_move_bg
          }
        _, _ ->
          case options.last_move_from, options.last_move_to {
            Some(from), _ if from == sq ->
              case is_light {
                True -> light_last_move_bg
                False -> dark_last_move_bg
              }
            _, Some(to) if to == sq ->
              case is_light {
                True -> light_last_move_bg
                False -> dark_last_move_bg
              }
            _, _ ->
              case is_light {
                True -> light_square_bg
                False -> dark_square_bg
              }
          }
      }
  }
}

fn string_repeat(s: String, n: Int) -> String {
  case n <= 0 {
    True -> ""
    False -> s <> string_repeat(s, n - 1)
  }
}
