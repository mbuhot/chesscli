//// Interprets etch commands into a 2D text grid for snapshot testing.
//// Ignores color/style commands; captures only text layout.

import etch/command
import etch/terminal
import gleam/dict.{type Dict}
import gleam/list
import gleam/string

/// Internal cursor state for processing commands.
type State {
  State(col: Int, row: Int, grid: Dict(#(Int, Int), String))
}

/// Render a list of etch commands to a plain text string.
/// Returns lines joined by newlines, each padded to the given width.
pub fn render_to_string(
  commands: List(command.Command),
  width: Int,
  height: Int,
) -> String {
  let initial = State(col: 0, row: 0, grid: dict.new())
  let final_state = list.fold(commands, initial, process_command)
  grid_to_string(final_state.grid, width, height)
}

fn process_command(state: State, cmd: command.Command) -> State {
  case cmd {
    command.MoveTo(col, row) -> State(..state, col: col, row: row)
    command.Print(text) -> print_text(state, text)
    command.Clear(terminal.UntilNewLine) -> state
    // Ignore all style/color/other commands
    _ -> state
  }
}

fn print_text(state: State, text: String) -> State {
  let graphemes = string.to_graphemes(text)
  let #(grid, col) =
    list.fold(graphemes, #(state.grid, state.col), fn(acc, g) {
      let #(grid, col) = acc
      let new_grid = dict.insert(grid, #(col, state.row), g)
      #(new_grid, col + 1)
    })
  State(..state, col: col, grid: grid)
}

fn grid_to_string(
  grid: Dict(#(Int, Int), String),
  width: Int,
  height: Int,
) -> String {
  list.range(0, height - 1)
  |> list.map(fn(row) { row_to_string(grid, row, width) })
  |> string.join("\n")
}

fn row_to_string(grid: Dict(#(Int, Int), String), row: Int, width: Int) -> String {
  list.range(0, width - 1)
  |> list.map(fn(col) {
    case dict.get(grid, #(col, row)) {
      Ok(ch) -> ch
      Error(_) -> " "
    }
  })
  |> string.concat
  |> string.trim_end
}
