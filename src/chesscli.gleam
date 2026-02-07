import chesscli/chess/game
import chesscli/chess/move_gen
import chesscli/tui/app.{type AppState}
import chesscli/tui/board_view.{RenderOptions}
import chesscli/tui/captures_view
import chesscli/tui/info_panel
import chesscli/tui/status_bar
import etch/command
import etch/event.{Key}
import etch/stdout
import etch/terminal
import gleam/javascript/promise
import gleam/list
import gleam/option.{None, Some}

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

  let state = app.new()
  render(state)
  loop(state)
}

fn render(state: AppState) -> Nil {
  let pos = game.current_position(state.game)
  let last = app.last_move(state)
  let check_square = case move_gen.is_in_check(pos, pos.active_color) {
    True -> move_gen.find_king(pos.board, pos.active_color)
    False -> None
  }
  let options =
    RenderOptions(
      from_white: state.from_white,
      last_move_from: option.map(last, fn(m) { m.from }),
      last_move_to: option.map(last, fn(m) { m.to }),
      check_square: check_square,
    )

  let board_commands = board_view.render(pos.board, options)
  let captures_commands =
    captures_view.render(pos.board, state.from_white, 0, 12, 4)
  let panel_commands = info_panel.render(state.game, 31, 1)
  let status_commands = status_bar.render(state, 13)

  stdout.execute(
    list.flatten([
      board_commands,
      captures_commands,
      panel_commands,
      status_commands,
    ]),
  )
}

fn loop(state: AppState) {
  use evt <- promise.await(event.read())
  case evt {
    Some(Ok(Key(k))) -> {
      let #(new_state, effect) = app.update(state, k.code)
      case effect {
        app.Quit -> {
          quit()
          use _ <- promise.new()
          Nil
        }
        app.Render -> {
          render(new_state)
          loop(new_state)
        }
        app.None -> loop(new_state)
      }
    }
    Some(Ok(event.Resize(_, _))) -> {
      stdout.execute([command.Clear(terminal.All)])
      render(state)
      loop(state)
    }
    _ -> loop(state)
  }
}

fn quit() -> Nil {
  stdout.execute([
    command.ShowCursor,
    command.LeaveAlternateScreen,
  ])
  exit(0)
}
