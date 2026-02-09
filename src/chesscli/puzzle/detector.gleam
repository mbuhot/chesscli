//// Extracts puzzles from game analysis by finding positions where the player
//// made a Miss, Mistake, or Blunder and a better move existed.

import chesscli/chess/color.{type Color}
import chesscli/chess/fen
import chesscli/chess/game.{type Game}
import chesscli/chess/move
import chesscli/engine/analysis.{
  type GameAnalysis, type MoveAnalysis, Blunder, Miss, Mistake,
}
import chesscli/engine/uci
import chesscli/puzzle/puzzle.{type Puzzle, Puzzle}
import gleam/dict
import gleam/list
import gleam/option.{type Option}

/// Extract puzzles from Miss, Mistake, and Blunder positions in a game.
/// When a player color is given, only returns puzzles for that color.
pub fn find_puzzles(
  ga: GameAnalysis,
  game: Game,
  player_color: Option(Color),
) -> List(Puzzle) {
  ga.move_analyses
  |> list.filter(fn(ma) { is_puzzle_worthy(ma) })
  |> list.filter_map(fn(ma) { build_puzzle(ma, game) })
  |> list.filter(fn(p) {
    case player_color {
      option.Some(c) -> p.player_color == c
      option.None -> True
    }
  })
}

fn is_puzzle_worthy(ma: MoveAnalysis) -> Bool {
  case ma.classification {
    Miss | Mistake | Blunder -> True
    _ -> False
  }
}

fn build_puzzle(ma: MoveAnalysis, game: Game) -> Result(Puzzle, Nil) {
  let idx = ma.move_index
  case list_at(game.positions, idx), list_at(game.moves, idx) {
    Ok(pos), Ok(played_move) -> {
      let fen_str = fen.to_string(pos)
      let source = format_source_label(game)
      let white = option.unwrap(option.from_result(dict.get(game.tags, "White")), "?")
      let black = option.unwrap(option.from_result(dict.get(game.tags, "Black")), "?")
      let preceding = case idx > 0 {
        True ->
          case list_at(game.moves, idx - 1) {
            Ok(m) -> move.to_uci(m)
            Error(_) -> ""
          }
        False -> ""
      }
      Ok(Puzzle(
        fen: fen_str,
        player_color: pos.active_color,
        solution_uci: ma.best_move_uci,
        played_uci: move.to_uci(played_move),
        continuation: ma.best_move_pv,
        eval_before: uci.format_score(ma.eval_before),
        eval_after: uci.format_score(ma.eval_after),
        source_label: source,
        classification: ma.classification,
        white_name: white,
        black_name: black,
        preceding_move_uci: preceding,
        solve_count: 0,
      ))
    }
    _, _ -> Error(Nil)
  }
}

fn format_source_label(game: Game) -> String {
  let white = option.unwrap(option.from_result(dict.get(game.tags, "White")), "?")
  let black = option.unwrap(option.from_result(dict.get(game.tags, "Black")), "?")
  let date = option.unwrap(option.from_result(dict.get(game.tags, "Date")), "")
  white <> " vs " <> black <> case date {
    "" -> ""
    d -> ", " <> d
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
