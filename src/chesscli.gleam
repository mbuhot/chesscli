import chesscli/chess/color
import chesscli/chess/fen
import chesscli/chess/game
import chesscli/chess/move
import chesscli/chess/move_gen
import chesscli/chess/position.{type Position}
import chesscli/chess/square
import chesscli/chesscom/client
import chesscli/config
import chesscli/engine/analysis
import chesscli/engine/stockfish
import chesscli/engine/uci
import chesscli/tui/app.{type AppState, GameBrowser}
import chesscli/tui/board_view.{RenderOptions}
import chesscli/tui/captures_view
import chesscli/tui/eval_bar
import chesscli/tui/game_browser_view
import chesscli/tui/info_panel
import chesscli/tui/sound
import chesscli/tui/status_bar
import etch/command
import etch/event.{type KeyCode, Key}
import etch/stdout
import etch/terminal
import gleam/javascript/promise
import gleam/list
import gleam/dict
import gleam/option.{type Option, None, Some}
import gleam/string

@external(javascript, "./chesscli/tui/tui_ffi.mjs", "exit")
fn exit(n: Int) -> Nil

/// Yield to the JS macro task queue via setTimeout, ensuring pending I/O
/// (stdin, Stockfish stdout) gets processed before we resume.
@external(javascript, "./chesscli/tui/tui_ffi.mjs", "sleep")
fn sleep(ms: Int) -> promise.Promise(Nil)

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
  loop(state, None)
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
  let #(best_from, best_to) = best_move_squares(state)
  let options =
    RenderOptions(
      from_white: state.from_white,
      last_move_from: option.map(last, fn(m) { m.from }),
      last_move_to: option.map(last, fn(m) { m.to }),
      check_square: check_square,
      best_move_from: best_from,
      best_move_to: best_to,
    )

  let board_commands = board_view.render(pos.board, options)
  let white_name = option.from_result(dict.get(state.game.tags, "White"))
  let black_name = option.from_result(dict.get(state.game.tags, "Black"))
  let captures_commands =
    captures_view.render(pos.board, state.from_white, 0, 12, 7, white_name, black_name)
  let panel_commands = info_panel.render(state.game, 34, 1, 10, state.analysis, state.deep_analysis_index)
  let eval_commands = render_eval_bar(state)
  let status_commands = status_bar.render(state, 13)

  stdout.execute(
    list.flatten([
      board_commands,
      captures_commands,
      panel_commands,
      eval_commands,
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

fn loop(state: AppState, engine: Option(stockfish.EngineProcess)) {
  // During deep analysis, yield to the JS event loop via setTimeout so
  // stdin and Stockfish I/O get processed, then check for events
  case state.deep_analysis_index {
    Some(_) -> {
      use _ <- promise.await(sleep(50))
      use evt <- promise.await(event.poll(0))
      case evt {
        Some(Ok(Key(k))) -> handle_input(state, k.code, engine)
        Some(Ok(event.Resize(_, _))) -> {
          stdout.execute([command.Clear(terminal.All)])
          render(state)
          loop(state, engine)
        }
        _ -> {
          // No user input — check if a pending evaluation has completed
          case engine {
            Some(eng) ->
              case stockfish.poll_result(eng) {
                Some(lines) -> on_deep_eval_done(state, lines, eng)
                option.None -> loop(state, engine)
              }
            option.None -> loop(state, engine)
          }
        }
      }
    }
    None -> {
      use evt <- promise.await(event.read())
      case evt {
        Some(Ok(Key(k))) -> handle_input(state, k.code, engine)
        Some(Ok(event.Resize(_, _))) -> {
          stdout.execute([command.Clear(terminal.All)])
          render(state)
          loop(state, engine)
        }
        _ -> loop(state, engine)
      }
    }
  }
}

/// Process a key event from the user.
fn handle_input(
  state: AppState,
  key_code: KeyCode,
  engine: Option(stockfish.EngineProcess),
) {
  let #(new_state, effect) = app.update(state, key_code)
  case effect {
    app.Render -> flush_then_render(state, new_state, engine)
    _ -> {
      apply_transition_effects(state, new_state)
      handle_effect(new_state, effect, engine)
    }
  }
}

/// Discard all queued events, then render and resume.
/// This prevents key-repeat events from piling up during slow renders.
fn flush_then_render(
  original_state: AppState,
  state: AppState,
  engine: Option(stockfish.EngineProcess),
) {
  use next <- promise.await(event.poll(0))
  case next {
    Some(_) -> flush_then_render(original_state, state, engine)
    None -> {
      apply_transition_effects(original_state, state)
      render(state)
      loop(state, engine)
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

fn handle_effect(
  state: AppState,
  effect: app.Effect,
  engine: Option(stockfish.EngineProcess),
) {
  case effect {
    app.Quit -> {
      stop_engine(engine)
      quit()
      use _ <- promise.new()
      Nil
    }
    app.Render -> {
      render(state)
      loop(state, engine)
    }
    app.None -> loop(state, engine)
    app.FetchArchives(username) -> {
      config.write_username(username)
      render(state)
      use result <- promise.await(client.fetch_archives(username))
      let #(new_state, eff) =
        app.on_fetch_result(state, app.ArchivesResult(result))
      handle_effect(new_state, eff, engine)
    }
    app.FetchGames(url) -> {
      render(state)
      use result <- promise.await(client.fetch_games(url))
      let #(new_state, eff) =
        app.on_fetch_result(state, app.GamesResult(result))
      handle_effect(new_state, eff, engine)
    }
    app.AnalyzeGame -> {
      stop_engine(engine)
      render(state)
      use eng <- promise.await(stockfish.start())
      use _ <- promise.await(stockfish.new_game(eng))
      let start_fen = fen.to_string(starting_position(state.game))
      let move_ucis = list.map(state.game.moves, move.to_uci)
      let positions = state.game.positions
      let total = list.length(state.game.moves)
      use result <- promise.await(
        evaluate_positions_incremental(eng, start_fen, move_ucis, positions, total, 0, state, []),
      )
      let #(evaluations, best_move_ucis) = result
      let active_colors =
        list.map(list.take(positions, total), fn(pos) { pos.active_color })
      let ga =
        analysis.build_game_analysis(
          evaluations,
          move_ucis,
          best_move_ucis,
          active_colors,
        )
      let #(new_state, eff) = app.on_analysis_result(state, ga)
      handle_effect(new_state, eff, Some(eng))
    }
    app.ContinueDeepAnalysis -> {
      case state.deep_analysis_index, engine {
        Some(idx), Some(eng) -> {
          let total_positions = list.length(state.game.positions)
          case idx >= total_positions {
            True -> {
              // Deep analysis complete
              let done_state =
                app.AppState(..state, deep_analysis_index: None)
              stockfish.stop(eng)
              render(done_state)
              loop(done_state, None)
            }
            False -> {
              // Start non-blocking evaluation — returns immediately
              let start_fen = fen.to_string(starting_position(state.game))
              let move_ucis = list.map(state.game.moves, move.to_uci)
              let moves_prefix = list.take(move_ucis, idx)
              let position_cmd =
                uci.format_position_with_moves(start_fen, moves_prefix)
              stockfish.start_evaluation(eng, position_cmd, 18)
              render(state)
              // Return to loop — it polls for results between input checks
              loop(state, Some(eng))
            }
          }
        }
        _, _ -> {
          render(state)
          loop(state, engine)
        }
      }
    }
    app.CancelDeepAnalysis -> {
      stop_engine(engine)
      render(state)
      // After cancel, start fresh analysis
      handle_effect(state, app.AnalyzeGame, None)
    }
  }
}

/// Get the starting position (first position) of a game.
fn starting_position(g: game.Game) -> Position {
  let assert [pos, ..] = g.positions
  pos
}

/// Process a completed deep evaluation result: update analysis, start next eval.
fn on_deep_eval_done(
  state: AppState,
  lines: List(String),
  eng: stockfish.EngineProcess,
) {
  let assert Some(idx) = state.deep_analysis_index
  let #(raw_eval, best) = parse_engine_output(lines)
  let assert Ok(pos) =
    list.drop(state.game.positions, idx) |> list.first
  let eval = case pos.active_color {
    color.White -> raw_eval
    color.Black -> uci.negate_score(raw_eval)
  }
  let #(new_state, _eff) = app.on_deep_eval_update(state, idx, eval, best)
  // If more positions remain, start the next evaluation non-blockingly
  case new_state.deep_analysis_index {
    Some(next_idx) -> {
      let total_positions = list.length(state.game.positions)
      case next_idx >= total_positions {
        True -> {
          let done_state =
            app.AppState(..new_state, deep_analysis_index: None)
          stockfish.stop(eng)
          render(done_state)
          loop(done_state, None)
        }
        False -> {
          let start_fen = fen.to_string(starting_position(state.game))
          let move_ucis = list.map(state.game.moves, move.to_uci)
          let moves_prefix = list.take(move_ucis, next_idx)
          let position_cmd =
            uci.format_position_with_moves(start_fen, moves_prefix)
          stockfish.start_evaluation(eng, position_cmd, 18)
          render(new_state)
          loop(new_state, Some(eng))
        }
      }
    }
    None -> {
      // Deep analysis complete
      stockfish.stop(eng)
      render(new_state)
      loop(new_state, None)
    }
  }
}

/// Stop the engine if it's running.
fn stop_engine(engine: Option(stockfish.EngineProcess)) -> Nil {
  case engine {
    Some(eng) -> stockfish.stop(eng)
    None -> Nil
  }
}

/// Recursively evaluate each position using incremental moves for TT reuse.
fn evaluate_positions_incremental(
  engine: stockfish.EngineProcess,
  start_fen: String,
  move_ucis: List(String),
  positions: List(Position),
  total: Int,
  done: Int,
  state: AppState,
  acc: List(#(uci.Score, String)),
) -> promise.Promise(#(List(uci.Score), List(String))) {
  case positions {
    [] -> {
      let pairs = list.reverse(acc)
      let evaluations = list.map(pairs, fn(p) { p.0 })
      let best_moves = list.map(pairs, fn(p) { p.1 })
      promise.resolve(#(evaluations, best_moves))
    }
    [pos, ..rest] -> {
      let moves_prefix = list.take(move_ucis, done)
      let position_cmd =
        uci.format_position_with_moves(start_fen, moves_prefix)
      use lines <- promise.await(
        stockfish.evaluate_incremental(engine, position_cmd, 10),
      )
      let #(raw_eval, best) = parse_engine_output(lines)
      // UCI scores are from side-to-move's perspective; normalize to white's
      let eval = case pos.active_color {
        color.White -> raw_eval
        color.Black -> uci.negate_score(raw_eval)
      }
      let new_acc = [#(eval, best), ..acc]
      let new_done = done + 1
      // Update progress and render
      let new_state =
        app.AppState(..state, analysis_progress: Some(#(new_done, total + 1)))
      render(new_state)
      evaluate_positions_incremental(
        engine, start_fen, move_ucis, rest, total, new_done, state, new_acc,
      )
    }
  }
}

/// Parse Stockfish output lines to extract the deepest evaluation and best move.
fn parse_engine_output(lines: List(String)) -> #(uci.Score, String) {
  let default_score = uci.Centipawns(0)
  let default_best = ""
  list.fold(lines, #(default_score, default_best), fn(acc, line) {
    case uci.parse_info(line) {
      Ok(info) -> #(info.score, acc.1)
      Error(_) ->
        case uci.parse_bestmove(line) {
          Ok(#(best, _)) -> #(acc.0, best)
          Error(_) -> acc
        }
    }
  })
}

/// Derive the best move squares from analysis for the current position.
fn best_move_squares(state: AppState) -> #(Option(square.Square), Option(square.Square)) {
  case state.analysis {
    Some(ga) -> {
      let idx = state.game.current_index
      case list.drop(ga.move_analyses, idx) |> list.first {
        Ok(ma) -> parse_uci_squares(ma.best_move_uci)
        Error(_) -> #(None, None)
      }
    }
    None -> #(None, None)
  }
}

/// Parse a UCI move string (e.g. "e2e4") into from/to squares.
fn parse_uci_squares(uci_str: String) -> #(Option(square.Square), Option(square.Square)) {
  let from_str = string.slice(uci_str, 0, 2)
  let to_str = string.slice(uci_str, 2, 2)
  let from = option.from_result(square.from_string(from_str))
  let to = option.from_result(square.from_string(to_str))
  #(from, to)
}

/// Render the eval bar when analysis is available.
fn render_eval_bar(state: AppState) -> List(command.Command) {
  case state.analysis {
    Some(ga) -> {
      let idx = state.game.current_index
      case list.drop(ga.evaluations, idx) |> list.first {
        Ok(score) -> eval_bar.render(score, 0, 2, 8)
        Error(_) -> []
      }
    }
    None -> []
  }
}

fn quit() -> Nil {
  stdout.execute([
    command.ShowCursor,
    command.LeaveAlternateScreen,
  ])
  exit(0)
}
