import chesscli/chess/board
import chesscli/chess/square
import chesscli/tui/board_view.{RenderOptions}
import etch/command
import etch/style
import gleam/list
import gleam/option.{None, Some}

// --- default_options ---

pub fn default_options_test() {
  let opts = board_view.default_options()
  assert opts.from_white == True
  assert opts.last_move_from == None
  assert opts.last_move_to == None
  assert opts.check_square == None
  assert opts.best_move_from == None
  assert opts.best_move_to == None
}

// --- Helper to extract SetBackgroundColor commands ---

fn bg_colors(commands: List(command.Command)) -> List(style.Color) {
  list.filter_map(commands, fn(cmd) {
    case cmd {
      command.SetBackgroundColor(c) -> Ok(c)
      _ -> Error(Nil)
    }
  })
}

// --- Last move highlights ---

pub fn last_move_highlights_appear_test() {
  let b = board.initial()
  let opts =
    RenderOptions(
      from_white: True,
      last_move_from: Some(square.e2),
      last_move_to: Some(square.e4),
      check_square: None,
      best_move_from: None,
      best_move_to: None,
    )
  let commands = board_view.render(b, opts)
  let colors = bg_colors(commands)
  // e2 is a light square (file 4 + rank 1 = 5, odd = light), e4 is also light
  // Last move light = Rgb(245, 246, 130)
  let last_move_light = style.Rgb(245, 246, 130)
  assert list.contains(colors, last_move_light) == True
}

pub fn last_move_dark_square_highlights_test() {
  let b = board.initial()
  let opts =
    RenderOptions(
      from_white: True,
      last_move_from: Some(square.d2),
      last_move_to: Some(square.d4),
      check_square: None,
      best_move_from: None,
      best_move_to: None,
    )
  let commands = board_view.render(b, opts)
  let colors = bg_colors(commands)
  // d2 is a dark square (file 3 + rank 1 = 4, even = dark)
  // d4 is also dark (file 3 + rank 3 = 6, even = dark)
  let last_move_dark = style.Rgb(186, 202, 68)
  assert list.contains(colors, last_move_dark) == True
}

// --- Check highlights ---

pub fn check_highlight_appears_test() {
  let b = board.initial()
  let opts =
    RenderOptions(
      from_white: True,
      last_move_from: None,
      last_move_to: None,
      check_square: Some(square.e1),
      best_move_from: None,
      best_move_to: None,
    )
  let commands = board_view.render(b, opts)
  let colors = bg_colors(commands)
  // e1 is a dark square (file 4 + rank 0 = 4, even = dark)
  let check_dark = style.Rgb(200, 100, 100)
  assert list.contains(colors, check_dark) == True
}

pub fn check_overrides_last_move_test() {
  // When a square is both a last-move target and the check square,
  // check color should win
  let b = board.initial()
  let opts =
    RenderOptions(
      from_white: True,
      last_move_from: Some(square.e2),
      last_move_to: Some(square.e1),
      check_square: Some(square.e1),
      best_move_from: None,
      best_move_to: None,
    )
  let commands = board_view.render(b, opts)
  let colors = bg_colors(commands)
  let check_dark = style.Rgb(200, 100, 100)
  // Check should appear (on e1 which is dark)
  assert list.contains(colors, check_dark) == True
}

// --- Best move highlights ---

pub fn best_move_light_square_highlights_test() {
  let b = board.initial()
  let opts =
    RenderOptions(
      from_white: True,
      last_move_from: None,
      last_move_to: None,
      check_square: None,
      best_move_from: Some(square.e2),
      best_move_to: Some(square.e4),
    )
  let commands = board_view.render(b, opts)
  let colors = bg_colors(commands)
  // e2 and e4 are light squares; best move light = Rgb(100, 160, 240)
  let best_move_light = style.Rgb(100, 160, 240)
  assert list.contains(colors, best_move_light) == True
}

pub fn best_move_dark_square_highlights_test() {
  let b = board.initial()
  let opts =
    RenderOptions(
      from_white: True,
      last_move_from: None,
      last_move_to: None,
      check_square: None,
      best_move_from: Some(square.d2),
      best_move_to: Some(square.d4),
    )
  let commands = board_view.render(b, opts)
  let colors = bg_colors(commands)
  // d2 and d4 are dark squares; best move dark = Rgb(60, 120, 200)
  let best_move_dark = style.Rgb(60, 120, 200)
  assert list.contains(colors, best_move_dark) == True
}

pub fn best_move_overrides_last_move_test() {
  let b = board.initial()
  let opts =
    RenderOptions(
      from_white: True,
      last_move_from: Some(square.e2),
      last_move_to: Some(square.e4),
      check_square: None,
      best_move_from: Some(square.e2),
      best_move_to: Some(square.d4),
    )
  let commands = board_view.render(b, opts)
  let colors = bg_colors(commands)
  // e2 has both best move and last move; best move should win
  let best_move_light = style.Rgb(100, 160, 240)
  assert list.contains(colors, best_move_light) == True
}

pub fn check_overrides_best_move_test() {
  let b = board.initial()
  let opts =
    RenderOptions(
      from_white: True,
      last_move_from: None,
      last_move_to: None,
      check_square: Some(square.e1),
      best_move_from: Some(square.e1),
      best_move_to: Some(square.e3),
    )
  let commands = board_view.render(b, opts)
  let colors = bg_colors(commands)
  // e1 has both check and best move; check should win
  let check_dark = style.Rgb(200, 100, 100)
  assert list.contains(colors, check_dark) == True
}

// --- No highlights when no options set ---

pub fn no_highlights_with_default_options_test() {
  let b = board.initial()
  let commands = board_view.render(b, board_view.default_options())
  let colors = bg_colors(commands)
  let last_move_light = style.Rgb(245, 246, 130)
  let last_move_dark = style.Rgb(186, 202, 68)
  let check_light = style.Rgb(235, 160, 160)
  let check_dark = style.Rgb(200, 100, 100)
  assert list.contains(colors, last_move_light) == False
  assert list.contains(colors, last_move_dark) == False
  assert list.contains(colors, check_light) == False
  assert list.contains(colors, check_dark) == False
  let best_move_light = style.Rgb(100, 160, 240)
  let best_move_dark = style.Rgb(60, 120, 200)
  assert list.contains(colors, best_move_light) == False
  assert list.contains(colors, best_move_dark) == False
}
