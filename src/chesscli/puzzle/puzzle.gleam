//// Puzzle types and training session management.
//// Extracts single-move puzzles from analysis mistakes and provides
//// progressive hints, move checking, and session navigation.

import chesscli/chess/board.{type Board}
import chesscli/chess/color.{type Color}
import chesscli/chess/fen
import chesscli/chess/move.{type Move}
import chesscli/chess/move_gen
import chesscli/chess/piece.{type Piece, Bishop, King, Knight, Pawn, Queen, Rook}
import chesscli/chess/position.{type Position}
import chesscli/chess/san
import chesscli/chess/square.{type Square}
import chesscli/engine/analysis.{type MoveClassification}
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string

/// A single puzzle derived from a game position where a better move existed.
pub type Puzzle {
  Puzzle(
    fen: String,
    player_color: Color,
    solution_uci: String,
    played_uci: String,
    continuation: List(String),
    eval_before: String,
    eval_after: String,
    source_label: String,
    classification: MoveClassification,
    white_name: String,
    black_name: String,
    /// The opponent's move that created the puzzle position (UCI string).
    preceding_move_uci: String,
    /// Consecutive clean solves (no hints). Puzzle is mastered at 3.
    solve_count: Int,
  )
}

/// Progressive reveal phases for a puzzle attempt.
pub type PuzzlePhase {
  Solving
  HintPiece
  HintSquare
  Correct
  Incorrect
  Revealed
}

/// Tracks progress through a list of puzzles.
pub type TrainingSession {
  TrainingSession(
    puzzles: List(Puzzle),
    current_index: Int,
    results: List(#(Int, PuzzlePhase)),
  )
}

/// Create a new training session from a list of puzzles.
pub fn new_session(puzzles: List(Puzzle)) -> TrainingSession {
  TrainingSession(puzzles: puzzles, current_index: 0, results: [])
}

/// Randomly shuffle a list of puzzles.
@external(javascript, "./puzzle_ffi.mjs", "shuffle_list")
pub fn shuffle(items: List(Puzzle)) -> List(Puzzle)

/// Get the puzzle at the current index, if any.
pub fn current_puzzle(session: TrainingSession) -> Option(Puzzle) {
  list_at(session.puzzles, session.current_index)
}

/// Check if a UCI move string matches the puzzle's solution.
pub fn check_move(puzzle: Puzzle, move_uci: String) -> Bool {
  string.lowercase(move_uci) == string.lowercase(puzzle.solution_uci)
}

/// Advance to the next puzzle.
pub fn next_puzzle(
  session: TrainingSession,
) -> Result(TrainingSession, Nil) {
  let next = session.current_index + 1
  case next < list.length(session.puzzles) {
    True -> Ok(TrainingSession(..session, current_index: next))
    False -> Error(Nil)
  }
}

/// Go back to the previous puzzle.
pub fn prev_puzzle(
  session: TrainingSession,
) -> Result(TrainingSession, Nil) {
  case session.current_index > 0 {
    True ->
      Ok(TrainingSession(..session, current_index: session.current_index - 1))
    False -> Error(Nil)
  }
}

/// Record the outcome phase for the current puzzle.
pub fn record_result(
  session: TrainingSession,
  phase: PuzzlePhase,
) -> TrainingSession {
  TrainingSession(
    ..session,
    results: [#(session.current_index, phase), ..session.results],
  )
}

/// Update the current puzzle's solve_count based on the outcome.
/// Clean solve (no hints) increments; hint or reveal resets to 0.
pub fn update_solve_count(
  session: TrainingSession,
  clean_solve: Bool,
) -> TrainingSession {
  let idx = session.current_index
  let puzzles =
    list.index_map(session.puzzles, fn(p, i) {
      case i == idx {
        True ->
          case clean_solve {
            True -> Puzzle(..p, solve_count: p.solve_count + 1)
            False -> Puzzle(..p, solve_count: 0)
          }
        False -> p
      }
    })
  TrainingSession(..session, puzzles: puzzles)
}

/// Remove puzzles that have been solved cleanly 3 or more times.
pub fn remove_mastered(puzzles: List(Puzzle)) -> List(Puzzle) {
  list.filter(puzzles, fn(p) { p.solve_count < 3 })
}

/// True when every puzzle in the session has a recorded result.
pub fn is_complete(session: TrainingSession) -> Bool {
  list.length(session.results) >= list.length(session.puzzles)
}

/// Restart a completed session: remove mastered puzzles, reshuffle,
/// and reset to a fresh session. Returns Error if no puzzles remain.
pub fn restart_session(
  session: TrainingSession,
) -> Result(TrainingSession, Nil) {
  let remaining = remove_mastered(session.puzzles)
  case remaining {
    [] -> Error(Nil)
    _ -> Ok(new_session(shuffle(remaining)))
  }
}

/// Session statistics: (total, solved, revealed).
pub fn stats(session: TrainingSession) -> #(Int, Int, Int) {
  let total = list.length(session.puzzles)
  let solved =
    list.count(session.results, fn(r) { r.1 == Correct })
  let revealed =
    list.count(session.results, fn(r) { r.1 == Revealed })
  #(total, solved, revealed)
}

/// First hint: which piece to move (e.g. "Move your knight").
pub fn hint_piece(puzzle: Puzzle, board: Board) -> String {
  let from_square = parse_from_square(puzzle.solution_uci)
  case from_square {
    option.Some(sq) ->
      case dict.get(board.pieces, sq) {
        Ok(cp) -> "Move your " <> piece_name(cp.piece)
        Error(_) -> "Look for a tactic"
      }
    option.None -> "Look for a tactic"
  }
}

/// Second hint: which piece and where (e.g. "Knight to f7").
pub fn hint_square(puzzle: Puzzle, board: Board) -> String {
  let from_square = parse_from_square(puzzle.solution_uci)
  let to_str = string.slice(puzzle.solution_uci, 2, 2)
  case from_square {
    option.Some(sq) ->
      case dict.get(board.pieces, sq) {
        Ok(cp) -> piece_name_capitalized(cp.piece) <> " to " <> to_str
        Error(_) -> "Move to " <> to_str
      }
    option.None -> "Move to " <> to_str
  }
}

fn parse_from_square(uci: String) -> Option(Square) {
  let from_str = string.slice(uci, 0, 2)
  option.from_result(square.from_string(from_str))
}

fn piece_name(p: Piece) -> String {
  case p {
    King -> "king"
    Queen -> "queen"
    Rook -> "rook"
    Bishop -> "bishop"
    Knight -> "knight"
    Pawn -> "pawn"
  }
}

fn piece_name_capitalized(p: Piece) -> String {
  case p {
    King -> "King"
    Queen -> "Queen"
    Rook -> "Rook"
    Bishop -> "Bishop"
    Knight -> "Knight"
    Pawn -> "Pawn"
  }
}

/// Convert a single UCI move to SAN given the position FEN.
/// Falls back to the raw UCI string if parsing fails.
pub fn format_uci_as_san(fen_str: String, uci: String) -> String {
  case fen.parse(fen_str) {
    Ok(pos) ->
      case resolve_uci(uci, pos) {
        Ok(m) -> san.to_string(m, pos)
        Error(_) -> uci
      }
    Error(_) -> uci
  }
}

/// Convert a puzzle's UCI continuation to SAN move list lines.
/// Returns lines like ["1...Nd7 2. Nf3 Bg7", "3. a4 O-O 4. Bc4 c5"].
pub fn format_continuation(puzzle: Puzzle, max_width: Int) -> List(String) {
  case puzzle.continuation {
    [] -> []
    uci_moves -> {
      case fen.parse(puzzle.fen) {
        Error(_) -> ["Line: " <> string.join(uci_moves, " ")]
        Ok(pos) -> {
          let san_pairs = uci_to_san_list(uci_moves, pos, [])
          let move_number = pos.fullmove_number
          let is_black = puzzle.player_color == color.Black
          format_san_lines(san_pairs, move_number, is_black, max_width)
        }
      }
    }
  }
}

fn uci_to_san_list(
  uci_moves: List(String),
  pos: Position,
  acc: List(String),
) -> List(String) {
  case uci_moves {
    [] -> list.reverse(acc)
    [uci, ..rest] -> {
      case resolve_uci(uci, pos) {
        Ok(m) -> {
          let san_str = san.to_string(m, pos)
          let new_pos = move.apply(pos, m)
          uci_to_san_list(rest, new_pos, [san_str, ..acc])
        }
        Error(_) -> {
          // If UCI parse fails, use raw UCI for remaining moves
          list.append(list.reverse(acc), [uci, ..rest])
        }
      }
    }
  }
}

/// Resolve a UCI string to a fully-flagged Move for a given position.
pub fn resolve_move(pos: Position, uci: String) -> Result(Move, Nil) {
  resolve_uci(uci, pos)
}

/// Apply a UCI move string to a position, returning the resulting position.
pub fn apply_uci(pos: Position, uci: String) -> Result(Position, Nil) {
  case resolve_uci(uci, pos) {
    Ok(m) -> Ok(move.apply(pos, m))
    Error(_) -> Error(Nil)
  }
}

/// Match a UCI string against legal moves to get a properly-flagged Move.
/// This ensures castling and en passant flags are set correctly for SAN output.
fn resolve_uci(uci: String, pos: Position) -> Result(Move, Nil) {
  case move.from_uci(uci) {
    Ok(raw) -> {
      let legal = move_gen.legal_moves(pos)
      case list.find(legal, fn(m) {
        m.from == raw.from && m.to == raw.to && m.promotion == raw.promotion
      }) {
        Ok(matched) -> Ok(matched)
        Error(_) -> Ok(raw)
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn format_san_lines(
  sans: List(String),
  start_move: Int,
  starts_with_black: Bool,
  max_width: Int,
) -> List(String) {
  let indexed = list.index_map(sans, fn(s, i) {
    let offset = case starts_with_black {
      True -> i + 1
      False -> i
    }
    let move_num = start_move + offset / 2
    let is_white = offset % 2 == 0
    case is_white {
      True -> int.to_string(move_num) <> ". " <> s
      False ->
        case i == 0 && starts_with_black {
          True -> int.to_string(move_num) <> "..." <> s
          False -> s
        }
    }
  })
  wrap_tokens(indexed, max_width, "", [])
}

fn wrap_tokens(
  tokens: List(String),
  max_width: Int,
  current_line: String,
  lines: List(String),
) -> List(String) {
  case tokens {
    [] ->
      case current_line {
        "" -> list.reverse(lines)
        _ -> list.reverse([current_line, ..lines])
      }
    [token, ..rest] -> {
      let candidate = case current_line {
        "" -> token
        _ -> current_line <> " " <> token
      }
      case string.length(candidate) > max_width && current_line != "" {
        True -> wrap_tokens(rest, max_width, token, [current_line, ..lines])
        False -> wrap_tokens(rest, max_width, candidate, lines)
      }
    }
  }
}

/// Copy solve_count from stored puzzles onto freshly detected ones.
pub fn restore_solve_counts(
  puzzles: List(Puzzle),
  stored: List(Puzzle),
) -> List(Puzzle) {
  let lookup =
    list.map(stored, fn(p) { #(p.fen <> "|" <> p.solution_uci, p.solve_count) })
  list.map(puzzles, fn(p) {
    let key = p.fen <> "|" <> p.solution_uci
    case list.key_find(lookup, key) {
      Ok(count) -> Puzzle(..p, solve_count: count)
      Error(_) -> p
    }
  })
}

/// Merge new puzzles into an existing list, deduplicating by FEN + solution,
/// keeping the most recent puzzles, capped at max_puzzles.
pub fn merge_puzzles(
  existing: List(Puzzle),
  new: List(Puzzle),
  max_puzzles: Int,
) -> List(Puzzle) {
  let combined = list.append(existing, new)
  let deduped = deduplicate(combined, [], [])
  list.take(deduped, max_puzzles)
}

fn deduplicate(
  puzzles: List(Puzzle),
  seen_keys: List(String),
  acc: List(Puzzle),
) -> List(Puzzle) {
  case puzzles {
    [] -> list.reverse(acc)
    [p, ..rest] -> {
      let key = p.fen <> "|" <> p.solution_uci
      case list.contains(seen_keys, key) {
        True -> deduplicate(rest, seen_keys, acc)
        False -> deduplicate(rest, [key, ..seen_keys], [p, ..acc])
      }
    }
  }
}

fn list_at(lst: List(a), index: Int) -> Option(a) {
  case lst, index {
    [], _ -> option.None
    [head, ..], 0 -> option.Some(head)
    [_, ..tail], n if n > 0 -> list_at(tail, n - 1)
    _, _ -> option.None
  }
}
