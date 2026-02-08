//// Renders the command menu overlay to the right of the board.
//// Shows mode-specific commands with highlighted shortcut keys.

import chesscli/tui/app.{type AppState, type MenuItem}
import etch/command
import etch/style
import etch/terminal
import gleam/list

/// Render the menu overlay at the given position.
pub fn render(
  state: AppState,
  start_col: Int,
  start_row: Int,
  max_height: Int,
) -> List(command.Command) {
  let items = app.menu_items(state)
  let header_cmds = [
    command.MoveTo(start_col, start_row),
    command.ResetStyle,
    command.SetAttributes([style.Bold]),
    command.Print("Commands"),
    command.ResetStyle,
    command.Print("          Esc: close"),
    command.Clear(terminal.UntilNewLine),
  ]
  let item_cmds =
    list.index_map(items, fn(item, i) {
      render_item(item, start_col, start_row + 1 + i)
    })
    |> list.flatten
  let used = 1 + list.length(items)
  let clear_cmds = clear_remaining(start_col, start_row + used, max_height - used)
  list.flatten([header_cmds, item_cmds, clear_cmds])
}

fn render_item(
  item: MenuItem,
  col: Int,
  row: Int,
) -> List(command.Command) {
  [
    command.MoveTo(col, row),
    command.ResetStyle,
    command.Print(" ["),
    command.SetForegroundColor(style.Rgb(0, 180, 220)),
    command.SetAttributes([style.Bold]),
    command.Print(item.key),
    command.ResetStyle,
    command.Print("] " <> item.label),
    command.Clear(terminal.UntilNewLine),
  ]
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
