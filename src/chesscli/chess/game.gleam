//// Manages game state for navigating through a chess game's move history
//// and for making new moves in free play mode.

import chesscli/chess/move.{type Move}
import chesscli/chess/move_gen
import chesscli/chess/pgn.{type PgnGame}
import chesscli/chess/position.{type Position}
import gleam/dict.{type Dict}
import gleam/int
import gleam/list

/// A navigable chess game with a full move/position history and a cursor
/// that tracks which position is currently being viewed.
pub type Game {
  Game(
    tags: Dict(String, String),
    positions: List(Position),
    moves: List(Move),
    current_index: Int,
  )
}

/// Errors from attempting to apply a move in free play mode.
pub type MoveError {
  IllegalMove
}

/// Create a Game from a parsed PGN.
pub fn from_pgn(pgn_game: PgnGame) -> Game {
  Game(
    tags: pgn_game.tags,
    positions: pgn_game.positions,
    moves: pgn_game.moves,
    current_index: 0,
  )
}

/// Create a game from an arbitrary position with no move history.
pub fn from_position(pos: Position) -> Game {
  Game(tags: dict.new(), positions: [pos], moves: [], current_index: 0)
}

/// Create a new game from the standard starting position.
pub fn new() -> Game {
  Game(
    tags: dict.new(),
    positions: [position.initial()],
    moves: [],
    current_index: 0,
  )
}

/// Get the position at the current index.
pub fn current_position(game: Game) -> Position {
  let assert Ok(pos) = list_at(game.positions, game.current_index)
  pos
}

/// Step forward one move. Returns Error if already at the end.
pub fn forward(game: Game) -> Result(Game, Nil) {
  case game.current_index < list.length(game.moves) {
    True -> Ok(Game(..game, current_index: game.current_index + 1))
    False -> Error(Nil)
  }
}

/// Step backward one move. Returns Error if already at the start.
pub fn backward(game: Game) -> Result(Game, Nil) {
  case game.current_index > 0 {
    True -> Ok(Game(..game, current_index: game.current_index - 1))
    False -> Error(Nil)
  }
}

/// Skip forward or backward by n moves, clamped to valid range.
pub fn skip(game: Game, n: Int) -> Game {
  let max = list.length(game.moves)
  let target = int.clamp(game.current_index + n, 0, max)
  Game(..game, current_index: target)
}

/// Jump to the start of the game.
pub fn goto_start(game: Game) -> Game {
  Game(..game, current_index: 0)
}

/// Jump to the end of the game (after the last move).
pub fn goto_end(game: Game) -> Game {
  Game(..game, current_index: list.length(game.moves))
}

/// Remove all moves and positions after the current index.
pub fn truncate(game: Game) -> Game {
  Game(
    ..game,
    moves: list.take(game.moves, game.current_index),
    positions: list.take(game.positions, game.current_index + 1),
  )
}

/// Apply a move to the current position in free play mode.
/// The move must be legal. Truncates any future moves/positions
/// if we're not at the end.
pub fn apply_move(game: Game, m: Move) -> Result(Game, MoveError) {
  let pos = current_position(game)
  let legal = move_gen.legal_moves(pos)
  case list.any(legal, fn(lm) { lm == m }) {
    False -> Error(IllegalMove)
    True -> {
      let new_pos = move.apply(pos, m)
      // Truncate positions and moves to current index, then append
      let positions = list.take(game.positions, game.current_index + 1)
      let moves = list.take(game.moves, game.current_index)
      Ok(Game(
        ..game,
        positions: list.append(positions, [new_pos]),
        moves: list.append(moves, [m]),
        current_index: game.current_index + 1,
      ))
    }
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
