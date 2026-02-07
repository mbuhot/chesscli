import chesscli/chess/board
import chesscli/chess/color
import chesscli/tui/board_view
import etch/command
import etch/event.{Char, Key}
import etch/stdout
import etch/terminal
import gleam/javascript/promise
import gleam/list
import gleam/option.{Some}

@external(javascript, "./chesscli/tui/tui_ffi.mjs", "exit")
fn exit(n: Int) -> Nil

pub fn main() {
  stdout.execute([
    command.EnterRaw,
    command.EnterAlternateScreen,
    command.HideCursor,
    command.Clear(terminal.All),
  ])

  event.init_event_server()

  let b = board.initial()
  render(b, True)
  loop(b, True)
}

fn render(b: board.Board, from_white: Bool) -> Nil {
  let commands = board_view.render(b, from_white)
  let status_row = 12
  let status_commands = [
    command.MoveTo(2, status_row),
    command.ResetStyle,
    command.Print(
      "[" <> color.to_string(color.White) <> " to move | f: flip | q: quit]",
    ),
  ]
  stdout.execute(list.flatten([commands, status_commands]))
}

fn loop(b: board.Board, from_white: Bool) {
  use evt <- promise.await(event.read())
  case evt {
    Some(Ok(Key(k))) ->
      case k.code {
        Char("q") -> {
          quit()
          use _ <- promise.new()
          Nil
        }
        Char("f") -> {
          let flipped = !from_white
          stdout.execute([command.Clear(terminal.All)])
          render(b, flipped)
          loop(b, flipped)
        }
        _ -> loop(b, from_white)
      }
    Some(Ok(event.Resize(_, _))) -> {
      stdout.execute([command.Clear(terminal.All)])
      render(b, from_white)
      loop(b, from_white)
    }
    _ -> loop(b, from_white)
  }
}

fn quit() -> Nil {
  stdout.execute([
    command.ShowCursor,
    command.LeaveAlternateScreen,
  ])
  exit(0)
}
