//// Move generation engine for chess.
//// Produces pseudo-legal and fully legal moves by combining piece movement
//// rules with check detection, castling validation, and game-over detection.

import chesscli/chess/board.{type Board}
import chesscli/chess/color.{type Color, Black, White}
import chesscli/chess/move.{type Move, Move}
import chesscli/chess/piece.{
  type Piece, Bishop, ColoredPiece, King, Knight, Pawn, Queen, Rook,
}
import chesscli/chess/position.{type Position}
import chesscli/chess/square.{type Square, Square}
import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}

/// Generate all pseudo-legal moves for the active color.
/// These moves may leave the king in check (filtering happens in legal_moves).
pub fn pseudo_legal_moves(pos: Position) -> List(Move) {
  let color = pos.active_color
  dict.fold(pos.board.pieces, [], fn(acc, sq, cp) {
    case cp.color == color {
      True -> list.append(piece_moves(pos, sq, cp), acc)
      False -> acc
    }
  })
}

fn piece_moves(
  pos: Position,
  sq: Square,
  cp: piece.ColoredPiece,
) -> List(Move) {
  case cp.piece {
    Pawn -> pawn_moves(pos, sq, cp.color)
    Knight -> knight_moves(pos, sq, cp.color)
    Bishop -> bishop_moves(pos, sq, cp.color)
    Rook -> rook_moves(pos, sq, cp.color)
    Queen -> queen_moves(pos, sq, cp.color)
    King -> king_moves(pos, sq, cp.color)
  }
}

// --- Pawn moves ---

fn pawn_moves(pos: Position, sq: Square, color: Color) -> List(Move) {
  let direction = case color {
    White -> 1
    Black -> -1
  }
  let start_rank = case color {
    White -> 1
    Black -> 6
  }
  let promo_rank = case color {
    White -> 7
    Black -> 0
  }

  let file_idx = square.file_to_int(sq.file)
  let rank_idx = square.rank_to_int(sq.rank)
  let target_rank = rank_idx + direction

  let moves = []

  // Single push
  let moves = case offset_square(file_idx, target_rank) {
    Some(target) ->
      case board.get(pos.board, target) {
        None ->
          case target_rank == promo_rank {
            True -> list.append(promotion_moves(sq, target), moves)
            False -> [
              Move(
                from: sq,
                to: target,
                promotion: None,
                is_castling: False,
                is_en_passant: False,
              ),
              ..moves
            ]
          }
        Some(_) -> moves
      }
    None -> moves
  }

  // Double push from starting rank
  let moves = case rank_idx == start_rank {
    True -> {
      let mid_rank = rank_idx + direction
      let double_rank = rank_idx + direction * 2
      case offset_square(file_idx, mid_rank), offset_square(file_idx, double_rank) {
        Some(mid), Some(target) ->
          case board.get(pos.board, mid), board.get(pos.board, target) {
            None, None -> [
              Move(
                from: sq,
                to: target,
                promotion: None,
                is_castling: False,
                is_en_passant: False,
              ),
              ..moves
            ]
            _, _ -> moves
          }
        _, _ -> moves
      }
    }
    False -> moves
  }

  // Captures (diagonal)
  let capture_files = [file_idx - 1, file_idx + 1]
  let moves =
    list.fold(capture_files, moves, fn(acc, cf) {
      case offset_square(cf, target_rank) {
        Some(target) ->
          case board.get(pos.board, target) {
            Some(ColoredPiece(c, _)) if c != color ->
              case target_rank == promo_rank {
                True -> list.append(promotion_moves(sq, target), acc)
                False -> [
                  Move(
                    from: sq,
                    to: target,
                    promotion: None,
                    is_castling: False,
                    is_en_passant: False,
                  ),
                  ..acc
                ]
              }
            _ -> acc
          }
        None -> acc
      }
    })

  // En passant captures
  let moves = case pos.en_passant {
    Some(ep_sq) -> {
      let ep_file = square.file_to_int(ep_sq.file)
      let ep_rank = square.rank_to_int(ep_sq.rank)
      case
        ep_rank == target_rank
        && { ep_file == file_idx - 1 || ep_file == file_idx + 1 }
      {
        True -> [
          Move(
            from: sq,
            to: ep_sq,
            promotion: None,
            is_castling: False,
            is_en_passant: True,
          ),
          ..moves
        ]
        False -> moves
      }
    }
    None -> moves
  }

  moves
}

fn promotion_moves(from: Square, to: Square) -> List(Move) {
  [Queen, Rook, Bishop, Knight]
  |> list.map(fn(p) {
    Move(from:, to:, promotion: Some(p), is_castling: False, is_en_passant: False)
  })
}

// --- Knight moves ---

fn knight_moves(pos: Position, sq: Square, color: Color) -> List(Move) {
  let file_idx = square.file_to_int(sq.file)
  let rank_idx = square.rank_to_int(sq.rank)
  let offsets = [
    #(1, 2),
    #(2, 1),
    #(2, -1),
    #(1, -2),
    #(-1, -2),
    #(-2, -1),
    #(-2, 1),
    #(-1, 2),
  ]

  list.filter_map(offsets, fn(offset) {
    let #(df, dr) = offset
    case offset_square(file_idx + df, rank_idx + dr) {
      Some(target) ->
        case board.get(pos.board, target) {
          None ->
            Ok(Move(
              from: sq,
              to: target,
              promotion: None,
              is_castling: False,
              is_en_passant: False,
            ))
          Some(ColoredPiece(c, _)) if c != color ->
            Ok(Move(
              from: sq,
              to: target,
              promotion: None,
              is_castling: False,
              is_en_passant: False,
            ))
          _ -> Error(Nil)
        }
      None -> Error(Nil)
    }
  })
}

// --- Sliding piece moves (bishop, rook, queen) ---

fn bishop_moves(pos: Position, sq: Square, color: Color) -> List(Move) {
  let directions = [#(1, 1), #(1, -1), #(-1, 1), #(-1, -1)]
  slide_moves(pos, sq, color, directions)
}

fn rook_moves(pos: Position, sq: Square, color: Color) -> List(Move) {
  let directions = [#(1, 0), #(-1, 0), #(0, 1), #(0, -1)]
  slide_moves(pos, sq, color, directions)
}

fn queen_moves(pos: Position, sq: Square, color: Color) -> List(Move) {
  let directions = [
    #(1, 0),
    #(-1, 0),
    #(0, 1),
    #(0, -1),
    #(1, 1),
    #(1, -1),
    #(-1, 1),
    #(-1, -1),
  ]
  slide_moves(pos, sq, color, directions)
}

fn slide_moves(
  pos: Position,
  sq: Square,
  color: Color,
  directions: List(#(Int, Int)),
) -> List(Move) {
  let file_idx = square.file_to_int(sq.file)
  let rank_idx = square.rank_to_int(sq.rank)
  list.flat_map(directions, fn(dir) {
    slide_ray(pos, sq, color, file_idx, rank_idx, dir.0, dir.1)
  })
}

fn slide_ray(
  pos: Position,
  from: Square,
  color: Color,
  file_idx: Int,
  rank_idx: Int,
  df: Int,
  dr: Int,
) -> List(Move) {
  let new_f = file_idx + df
  let new_r = rank_idx + dr
  case offset_square(new_f, new_r) {
    None -> []
    Some(target) ->
      case board.get(pos.board, target) {
        None -> [
          Move(
            from:,
            to: target,
            promotion: None,
            is_castling: False,
            is_en_passant: False,
          ),
          ..slide_ray(pos, from, color, new_f, new_r, df, dr)
        ]
        Some(ColoredPiece(c, _)) if c != color -> [
          Move(
            from:,
            to: target,
            promotion: None,
            is_castling: False,
            is_en_passant: False,
          ),
        ]
        _ -> []
      }
  }
}

// --- King moves ---

fn king_moves(pos: Position, sq: Square, color: Color) -> List(Move) {
  let file_idx = square.file_to_int(sq.file)
  let rank_idx = square.rank_to_int(sq.rank)
  let offsets = [
    #(1, 0),
    #(-1, 0),
    #(0, 1),
    #(0, -1),
    #(1, 1),
    #(1, -1),
    #(-1, 1),
    #(-1, -1),
  ]

  let normal_moves =
    list.filter_map(offsets, fn(offset) {
      let #(df, dr) = offset
      case offset_square(file_idx + df, rank_idx + dr) {
        Some(target) ->
          case board.get(pos.board, target) {
            None ->
              Ok(Move(
                from: sq,
                to: target,
                promotion: None,
                is_castling: False,
                is_en_passant: False,
              ))
            Some(ColoredPiece(c, _)) if c != color ->
              Ok(Move(
                from: sq,
                to: target,
                promotion: None,
                is_castling: False,
                is_en_passant: False,
              ))
            _ -> Error(Nil)
          }
        None -> Error(Nil)
      }
    })

  let castling_moves = generate_castling_moves(pos, color)
  list.append(normal_moves, castling_moves)
}

fn generate_castling_moves(pos: Position, color: Color) -> List(Move) {
  let #(king_sq, rank, can_kingside, can_queenside) = case color {
    White -> #(
      Square(square.E, square.R1),
      square.R1,
      pos.castling.white_kingside,
      pos.castling.white_queenside,
    )
    Black -> #(
      Square(square.E, square.R8),
      square.R8,
      pos.castling.black_kingside,
      pos.castling.black_queenside,
    )
  }

  let moves = []

  // Kingside: squares f and g must be empty
  let moves = case can_kingside {
    True ->
      case
        board.get(pos.board, Square(square.F, rank)),
        board.get(pos.board, Square(square.G, rank))
      {
        None, None -> [
          Move(
            from: king_sq,
            to: Square(square.G, rank),
            promotion: None,
            is_castling: True,
            is_en_passant: False,
          ),
          ..moves
        ]
        _, _ -> moves
      }
    False -> moves
  }

  // Queenside: squares b, c, d must be empty
  let moves = case can_queenside {
    True ->
      case
        board.get(pos.board, Square(square.B, rank)),
        board.get(pos.board, Square(square.C, rank)),
        board.get(pos.board, Square(square.D, rank))
      {
        None, None, None -> [
          Move(
            from: king_sq,
            to: Square(square.C, rank),
            promotion: None,
            is_castling: True,
            is_en_passant: False,
          ),
          ..moves
        ]
        _, _, _ -> moves
      }
    False -> moves
  }

  moves
}

// --- Helpers ---

/// Create a square from file/rank indices, returning None if out of bounds.
fn offset_square(file_idx: Int, rank_idx: Int) -> Option(Square) {
  case
    file_idx >= 0
    && file_idx < 8
    && rank_idx >= 0
    && rank_idx < 8
  {
    True -> {
      let assert Ok(file) = square.file_from_int(file_idx)
      let assert Ok(rank) = square.rank_from_int(rank_idx)
      Some(Square(file, rank))
    }
    False -> None
  }
}

/// Check if a square is attacked by a given color.
/// Used for check detection and castling validation.
pub fn is_square_attacked(
  pos: Position,
  sq: Square,
  by_color: Color,
) -> Bool {
  let file_idx = square.file_to_int(sq.file)
  let rank_idx = square.rank_to_int(sq.rank)

  is_attacked_by_pawn(pos.board, sq, file_idx, rank_idx, by_color)
  || is_attacked_by_knight(pos.board, file_idx, rank_idx, by_color)
  || is_attacked_by_sliding(pos.board, file_idx, rank_idx, by_color, Bishop, [
    #(1, 1),
    #(1, -1),
    #(-1, 1),
    #(-1, -1),
  ])
  || is_attacked_by_sliding(pos.board, file_idx, rank_idx, by_color, Rook, [
    #(1, 0),
    #(-1, 0),
    #(0, 1),
    #(0, -1),
  ])
  || is_attacked_by_king(pos.board, file_idx, rank_idx, by_color)
}

fn is_attacked_by_pawn(
  board: Board,
  _sq: Square,
  file_idx: Int,
  rank_idx: Int,
  by_color: Color,
) -> Bool {
  // Pawns attack diagonally; check from the target square's perspective
  let pawn_rank = case by_color {
    White -> rank_idx - 1
    Black -> rank_idx + 1
  }
  let pawn_files = [file_idx - 1, file_idx + 1]
  list.any(pawn_files, fn(pf) {
    case offset_square(pf, pawn_rank) {
      Some(attacker_sq) ->
        board.get(board, attacker_sq) == Some(ColoredPiece(by_color, Pawn))
      None -> False
    }
  })
}

fn is_attacked_by_knight(
  board: Board,
  file_idx: Int,
  rank_idx: Int,
  by_color: Color,
) -> Bool {
  let offsets = [
    #(1, 2),
    #(2, 1),
    #(2, -1),
    #(1, -2),
    #(-1, -2),
    #(-2, -1),
    #(-2, 1),
    #(-1, 2),
  ]
  list.any(offsets, fn(offset) {
    let #(df, dr) = offset
    case offset_square(file_idx + df, rank_idx + dr) {
      Some(attacker_sq) ->
        board.get(board, attacker_sq)
        == Some(ColoredPiece(by_color, Knight))
      None -> False
    }
  })
}

fn is_attacked_by_sliding(
  board: Board,
  file_idx: Int,
  rank_idx: Int,
  by_color: Color,
  piece: Piece,
  directions: List(#(Int, Int)),
) -> Bool {
  list.any(directions, fn(dir) {
    check_ray(board, file_idx, rank_idx, dir.0, dir.1, by_color, piece)
  })
}

fn check_ray(
  board: Board,
  file_idx: Int,
  rank_idx: Int,
  df: Int,
  dr: Int,
  by_color: Color,
  piece: Piece,
) -> Bool {
  let new_f = file_idx + df
  let new_r = rank_idx + dr
  case offset_square(new_f, new_r) {
    None -> False
    Some(sq) ->
      case board.get(board, sq) {
        None -> check_ray(board, new_f, new_r, df, dr, by_color, piece)
        Some(ColoredPiece(c, p)) ->
          c == by_color && { p == piece || p == Queen }
      }
  }
}

fn is_attacked_by_king(
  board: Board,
  file_idx: Int,
  rank_idx: Int,
  by_color: Color,
) -> Bool {
  let offsets = [
    #(1, 0),
    #(-1, 0),
    #(0, 1),
    #(0, -1),
    #(1, 1),
    #(1, -1),
    #(-1, 1),
    #(-1, -1),
  ]
  list.any(offsets, fn(offset) {
    let #(df, dr) = offset
    case offset_square(file_idx + df, rank_idx + dr) {
      Some(attacker_sq) ->
        board.get(board, attacker_sq) == Some(ColoredPiece(by_color, King))
      None -> False
    }
  })
}

/// Check if the given color's king is in check.
pub fn is_in_check(pos: Position, color: Color) -> Bool {
  case find_king(pos.board, color) {
    Some(king_sq) -> is_square_attacked(pos, king_sq, color.opposite(color))
    None -> False
  }
}

fn find_king(board: Board, color: Color) -> Option(Square) {
  dict.fold(board.pieces, None, fn(acc, sq, cp) {
    case acc {
      Some(_) -> acc
      None ->
        case cp {
          ColoredPiece(c, King) if c == color -> Some(sq)
          _ -> None
        }
    }
  })
}

/// Generate all legal moves for the active color.
/// Filters pseudo-legal moves to remove those that leave the king in check.
/// Also validates castling through check.
pub fn legal_moves(pos: Position) -> List(Move) {
  pseudo_legal_moves(pos)
  |> list.filter(fn(m) { is_legal(pos, m) })
}

fn is_legal(pos: Position, m: Move) -> Bool {
  let new_pos = move.apply(pos, m)
  // After making the move, the player who just moved should not be in check
  let not_in_check = !is_in_check(new_pos, pos.active_color)

  // For castling, also check that the king doesn't pass through or start in check
  case m.is_castling {
    False -> not_in_check
    True -> {
      // King can't castle out of check
      let not_starting_in_check =
        !is_in_check(pos, pos.active_color)
      // King can't pass through check (intermediate square)
      let from_file = square.file_to_int(m.from.file)
      let to_file = square.file_to_int(m.to.file)
      let mid_file = case to_file > from_file {
        True -> from_file + 1
        False -> from_file - 1
      }
      let assert Ok(mid_file_val) = square.file_from_int(mid_file)
      let mid_sq = Square(mid_file_val, m.from.rank)
      let mid_pos =
        move.apply(pos, Move(
          from: m.from,
          to: mid_sq,
          promotion: None,
          is_castling: False,
          is_en_passant: False,
        ))
      let not_through_check = !is_in_check(mid_pos, pos.active_color)

      not_in_check && not_starting_in_check && not_through_check
    }
  }
}

/// Outcome of evaluating the current position for game-ending conditions.
pub type GameStatus {
  InProgress
  Checkmate
  Stalemate
  Draw
}

/// Determine whether the game is ongoing, drawn, or ended by checkmate/stalemate.
pub fn game_status(pos: Position) -> GameStatus {
  case legal_moves(pos) {
    [] ->
      case is_in_check(pos, pos.active_color) {
        True -> Checkmate
        False -> Stalemate
      }
    _ ->
      case pos.halfmove_clock >= 100 {
        True -> Draw
        False -> InProgress
      }
  }
}
