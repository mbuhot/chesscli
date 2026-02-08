import chesscli/chess/color.{Black, White}
import chesscli/chess/game
import chesscli/chess/pgn
import chesscli/engine/analysis.{
  Best, Blunder, Excellent, GameAnalysis, Good, Inaccuracy, Miss, Mistake,
  MoveAnalysis,
}
import chesscli/engine/uci.{Centipawns}
import chesscli/puzzle/detector
import gleam/list
import gleam/option
import gleam/string

fn sample_game() -> game.Game {
  let assert Ok(pgn_game) =
    pgn.parse(
      "[White \"Alice\"]
[Black \"Bob\"]
[Date \"2024.01.15\"]

1. e4 e5 2. Nf3 Nc6",
    )
  game.from_pgn(pgn_game)
}

// --- find_puzzles ---

pub fn find_puzzles_extracts_mistake_test() {
  let g = sample_game()
  // Move index 1 is Black's move (e7e5). Engine says d7d5 was better.
  let ga =
    GameAnalysis(evaluations: [], move_analyses: [
      MoveAnalysis(0, Centipawns(0), Centipawns(20), "e2e4", [], Best),
      MoveAnalysis(
        1, Centipawns(20), Centipawns(170), "d7d5", ["d7d5", "e4d5"], Mistake,
      ),
      MoveAnalysis(2, Centipawns(170), Centipawns(180), "g1f3", [], Best),
      MoveAnalysis(3, Centipawns(180), Centipawns(190), "b8c6", [], Best),
    ])
  let puzzles = detector.find_puzzles(ga, g, option.None)
  assert list.length(puzzles) == 1
  let assert [p] = puzzles
  assert p.classification == Mistake
  assert p.solution_uci == "d7d5"
  assert p.played_uci == "e7e5"
  assert p.player_color == Black
}

pub fn find_puzzles_extracts_blunder_test() {
  let g = sample_game()
  let ga =
    GameAnalysis(evaluations: [], move_analyses: [
      MoveAnalysis(0, Centipawns(0), Centipawns(-250), "d2d4", ["e2e4"], Blunder),
      MoveAnalysis(1, Centipawns(-250), Centipawns(-240), "e7e5", [], Best),
      MoveAnalysis(2, Centipawns(-240), Centipawns(-230), "g1f3", [], Best),
      MoveAnalysis(3, Centipawns(-230), Centipawns(-220), "b8c6", [], Best),
    ])
  let puzzles = detector.find_puzzles(ga, g, option.None)
  assert list.length(puzzles) == 1
  let assert [p] = puzzles
  assert p.classification == Blunder
  assert p.player_color == White
}

pub fn find_puzzles_extracts_miss_test() {
  let g = sample_game()
  let ga =
    GameAnalysis(evaluations: [], move_analyses: [
      MoveAnalysis(0, Centipawns(200), Centipawns(150), "d2d4", ["e2e4"], Miss),
      MoveAnalysis(1, Centipawns(150), Centipawns(160), "e7e5", [], Best),
      MoveAnalysis(2, Centipawns(160), Centipawns(170), "g1f3", [], Best),
      MoveAnalysis(3, Centipawns(170), Centipawns(180), "b8c6", [], Best),
    ])
  let puzzles = detector.find_puzzles(ga, g, option.None)
  assert list.length(puzzles) == 1
  let assert [p] = puzzles
  assert p.classification == Miss
}

pub fn find_puzzles_ignores_good_moves_test() {
  let g = sample_game()
  let ga =
    GameAnalysis(evaluations: [], move_analyses: [
      MoveAnalysis(0, Centipawns(0), Centipawns(20), "e2e4", [], Best),
      MoveAnalysis(1, Centipawns(20), Centipawns(15), "e7e5", [], Excellent),
      MoveAnalysis(2, Centipawns(15), Centipawns(10), "g1f3", [], Good),
      MoveAnalysis(3, Centipawns(10), Centipawns(30), "b8c6", [], Inaccuracy),
    ])
  let puzzles = detector.find_puzzles(ga, g, option.None)
  assert puzzles == []
}

pub fn find_puzzles_correct_fen_and_source_test() {
  let g = sample_game()
  let ga =
    GameAnalysis(evaluations: [], move_analyses: [
      MoveAnalysis(0, Centipawns(0), Centipawns(-250), "d2d4", [], Blunder),
      MoveAnalysis(1, Centipawns(-250), Centipawns(-240), "e7e5", [], Best),
      MoveAnalysis(2, Centipawns(-240), Centipawns(-230), "g1f3", [], Best),
      MoveAnalysis(3, Centipawns(-230), Centipawns(-220), "b8c6", [], Best),
    ])
  let puzzles = detector.find_puzzles(ga, g, option.None)
  let assert [p] = puzzles
  // FEN should be the starting position (before move 0)
  assert string.contains(p.fen, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR")
  assert p.source_label == "Alice vs Bob, 2024.01.15"
}

pub fn find_puzzles_mixed_game_test() {
  // Game with Mistake, Blunder, and Miss — all three extracted
  let g = sample_game()
  let ga =
    GameAnalysis(evaluations: [], move_analyses: [
      MoveAnalysis(0, Centipawns(200), Centipawns(150), "d2d4", [], Miss),
      MoveAnalysis(1, Centipawns(150), Centipawns(300), "d7d5", [], Mistake),
      MoveAnalysis(2, Centipawns(300), Centipawns(-100), "a2a3", [], Blunder),
      MoveAnalysis(3, Centipawns(-100), Centipawns(-90), "b8c6", [], Best),
    ])
  let puzzles = detector.find_puzzles(ga, g, option.None)
  assert list.length(puzzles) == 3
}

pub fn find_puzzles_empty_analysis_test() {
  let g = sample_game()
  let ga = GameAnalysis(evaluations: [], move_analyses: [])
  let puzzles = detector.find_puzzles(ga, g, option.None)
  assert puzzles == []
}

pub fn find_puzzles_continuation_preserved_test() {
  let g = sample_game()
  let pv = ["d7d5", "e4d5", "d8d5"]
  let ga =
    GameAnalysis(evaluations: [], move_analyses: [
      MoveAnalysis(0, Centipawns(0), Centipawns(20), "e2e4", [], Best),
      MoveAnalysis(1, Centipawns(20), Centipawns(170), "d7d5", pv, Mistake),
      MoveAnalysis(2, Centipawns(170), Centipawns(180), "g1f3", [], Best),
      MoveAnalysis(3, Centipawns(180), Centipawns(190), "b8c6", [], Best),
    ])
  let puzzles = detector.find_puzzles(ga, g, option.None)
  let assert [p] = puzzles
  assert p.continuation == pv
}

pub fn find_puzzles_filters_by_player_color_test() {
  // Mistakes from both sides, but only Black's should be returned
  let g = sample_game()
  let ga =
    GameAnalysis(evaluations: [], move_analyses: [
      MoveAnalysis(0, Centipawns(0), Centipawns(-250), "d2d4", [], Blunder),
      MoveAnalysis(1, Centipawns(-250), Centipawns(100), "d7d5", [], Mistake),
      MoveAnalysis(2, Centipawns(100), Centipawns(-100), "a2a3", [], Blunder),
      MoveAnalysis(3, Centipawns(-100), Centipawns(-90), "b8c6", [], Best),
    ])
  let puzzles = detector.find_puzzles(ga, g, option.Some(Black))
  assert list.length(puzzles) == 1
  let assert [p] = puzzles
  assert p.player_color == Black
}

pub fn find_puzzles_filters_white_only_test() {
  let g = sample_game()
  let ga =
    GameAnalysis(evaluations: [], move_analyses: [
      MoveAnalysis(0, Centipawns(0), Centipawns(-250), "d2d4", [], Blunder),
      MoveAnalysis(1, Centipawns(-250), Centipawns(100), "d7d5", [], Mistake),
      MoveAnalysis(2, Centipawns(100), Centipawns(-100), "a2a3", [], Blunder),
      MoveAnalysis(3, Centipawns(-100), Centipawns(-90), "b8c6", [], Best),
    ])
  let puzzles = detector.find_puzzles(ga, g, option.Some(White))
  assert list.length(puzzles) == 2
  let assert [p1, p2] = puzzles
  assert p1.player_color == White
  assert p2.player_color == White
}
