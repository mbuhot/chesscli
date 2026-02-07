import chesscli/chess/game
import chesscli/chess/move_gen
import chesscli/chesscom/client
import chesscli/config
import chesscli/tui/app.{type AppState, GameBrowser}
import chesscli/tui/board_view.{RenderOptions}
import chesscli/tui/captures_view
import chesscli/tui/game_browser_view
import chesscli/tui/info_panel
import chesscli/tui/sound
import chesscli/tui/status_bar
import etch/command
import etch/event.{Key}
import etch/stdout
import etch/terminal
import gleam/javascript/promise
import gleam/list
import gleam/dict
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

  let saved_username = config.read_username()
  let state = app.AppState(..app.new(), last_username: saved_username)
  render(state)
  loop(state)
}

fn render(state: AppState) -> Nil {
  case state.mode {
    GameBrowser -> render_browser(state)
    _ -> render_board(state)
  }
}

fn render_board(state: AppState) -> Nil {
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
  let white_name = option.from_result(dict.get(state.game.tags, "White"))
  let black_name = option.from_result(dict.get(state.game.tags, "Black"))
  let captures_commands =
    captures_view.render(pos.board, state.from_white, 0, 12, 4, white_name, black_name)
  let panel_commands = info_panel.render(state.game, 31, 1, 10)
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

fn render_browser(state: AppState) -> Nil {
  let browser_commands = game_browser_view.render(state)
  let status_commands = status_bar.render(state, 13)
  stdout.execute(
    list.flatten([
      [command.Clear(terminal.All)],
      browser_commands,
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
        app.Render -> flush_then_render(state, new_state)
        _ -> {
          apply_transition_effects(state, new_state)
          handle_effect(new_state, effect)
        }
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

/// Discard all queued events, then render and resume.
/// This prevents key-repeat events from piling up during slow renders.
fn flush_then_render(original_state: AppState, state: AppState) {
  use next <- promise.await(event.poll(0))
  case next {
    Some(_) -> flush_then_render(original_state, state)
    None -> {
      apply_transition_effects(original_state, state)
      render(state)
      loop(state)
    }
  }
}

fn apply_transition_effects(
  original_state: AppState,
  state: AppState,
) -> Nil {
  case sound.determine_sound(original_state, state) {
    Some(s) -> sound.play(s)
    None -> Nil
  }
  case original_state.mode, state.mode {
    GameBrowser, GameBrowser -> Nil
    GameBrowser, _ -> stdout.execute([command.Clear(terminal.All)])
    _, _ -> Nil
  }
}

fn handle_effect(state: AppState, effect: app.Effect) {
  case effect {
    app.Quit -> {
      quit()
      use _ <- promise.new()
      Nil
    }
    app.Render -> {
      render(state)
      loop(state)
    }
    app.None -> loop(state)
    app.FetchArchives(username) -> {
      config.write_username(username)
      render(state)
      use result <- promise.await(client.fetch_archives(username))
      let #(new_state, eff) =
        app.on_fetch_result(state, app.ArchivesResult(result))
      handle_effect(new_state, eff)
    }
    app.FetchGames(url) -> {
      render(state)
      use result <- promise.await(client.fetch_games(url))
      let #(new_state, eff) =
        app.on_fetch_result(state, app.GamesResult(result))
      handle_effect(new_state, eff)
    }
    app.AnalyzeGame -> {
      // Full implementation in Step 10 — for now just render and continue
      render(state)
      loop(state)
    }
  }
}

fn quit() -> Nil {
  stdout.execute([
    command.ShowCursor,
    command.LeaveAlternateScreen,
  ])
  exit(0)
}
