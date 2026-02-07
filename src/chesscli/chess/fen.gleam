import chesscli/chess/board.{type Board, Board}
import chesscli/chess/color.{Black, White}
import chesscli/chess/piece.{type ColoredPiece}
import chesscli/chess/position.{type CastlingRights, type Position, CastlingRights, Position}
import chesscli/chess/square.{type Square, Square}
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type FenError {
  InvalidBoard(String)
  InvalidActiveColor(String)
  InvalidCastling(String)
  InvalidEnPassant(String)
  InvalidHalfmoveClock(String)
  InvalidFullmoveNumber(String)
}

pub fn parse(fen: String) -> Result(Position, FenError) {
  case string.split(fen, " ") {
    [board_str, color_str, castling_str, ep_str, halfmove_str, fullmove_str] -> {
      use board <- result.try(parse_board(board_str))
      use active_color <- result.try(parse_active_color(color_str))
      use castling <- result.try(parse_castling(castling_str))
      use en_passant <- result.try(parse_en_passant(ep_str))
      use halfmove_clock <- result.try(parse_halfmove_clock(halfmove_str))
      use fullmove_number <- result.try(parse_fullmove_number(fullmove_str))
      Ok(Position(
        board:,
        active_color:,
        castling:,
        en_passant:,
        halfmove_clock:,
        fullmove_number:,
      ))
    }
    _ -> Error(InvalidBoard("expected 6 fields"))
  }
}

pub fn to_string(pos: Position) -> String {
  [
    board_to_string(pos.board),
    active_color_to_string(pos.active_color),
    castling_to_string(pos.castling),
    en_passant_to_string(pos.en_passant),
    int.to_string(pos.halfmove_clock),
    int.to_string(pos.fullmove_number),
  ]
  |> string.join(" ")
}

fn parse_board(s: String) -> Result(Board, FenError) {
  let ranks = string.split(s, "/")
  case list.length(ranks) {
    8 -> {
      // FEN ranks go from rank 8 (top) to rank 1 (bottom)
      let rank_indices = [7, 6, 5, 4, 3, 2, 1, 0]
      parse_ranks(ranks, rank_indices, dict.new())
    }
    _ -> Error(InvalidBoard("expected 8 ranks"))
  }
}

fn parse_ranks(
  ranks: List(String),
  rank_indices: List(Int),
  pieces: dict.Dict(Square, ColoredPiece),
) -> Result(Board, FenError) {
  case ranks, rank_indices {
    [], [] -> Ok(Board(pieces:))
    [rank_str, ..rest_ranks], [rank_idx, ..rest_indices] -> {
      use new_pieces <- result.try(parse_rank(rank_str, rank_idx, pieces))
      parse_ranks(rest_ranks, rest_indices, new_pieces)
    }
    _, _ -> Error(InvalidBoard("rank count mismatch"))
  }
}

fn parse_rank(
  s: String,
  rank_idx: Int,
  pieces: dict.Dict(Square, ColoredPiece),
) -> Result(dict.Dict(Square, ColoredPiece), FenError) {
  let assert Ok(rank) = square.rank_from_int(rank_idx)
  parse_rank_chars(string.to_graphemes(s), 0, rank, pieces)
}

fn parse_rank_chars(
  chars: List(String),
  file_idx: Int,
  rank: square.Rank,
  pieces: dict.Dict(Square, ColoredPiece),
) -> Result(dict.Dict(Square, ColoredPiece), FenError) {
  case chars {
    [] ->
      case file_idx {
        8 -> Ok(pieces)
        _ -> Error(InvalidBoard("rank has wrong number of squares"))
      }
    [char, ..rest] -> {
      case int.parse(char) {
        Ok(n) -> parse_rank_chars(rest, file_idx + n, rank, pieces)
        Error(_) -> {
          case piece.from_fen_char(char) {
            Ok(colored_piece) -> {
              let assert Ok(file) = square.file_from_int(file_idx)
              let sq = Square(file, rank)
              let new_pieces = dict.insert(pieces, sq, colored_piece)
              parse_rank_chars(rest, file_idx + 1, rank, new_pieces)
            }
            Error(_) ->
              Error(InvalidBoard("invalid piece character: " <> char))
          }
        }
      }
    }
  }
}

fn parse_active_color(s: String) -> Result(color.Color, FenError) {
  case s {
    "w" -> Ok(White)
    "b" -> Ok(Black)
    _ -> Error(InvalidActiveColor(s))
  }
}

fn parse_castling(s: String) -> Result(CastlingRights, FenError) {
  case s {
    "-" ->
      Ok(CastlingRights(
        white_kingside: False,
        white_queenside: False,
        black_kingside: False,
        black_queenside: False,
      ))
    _ ->
      Ok(CastlingRights(
        white_kingside: string.contains(s, "K"),
        white_queenside: string.contains(s, "Q"),
        black_kingside: string.contains(s, "k"),
        black_queenside: string.contains(s, "q"),
      ))
  }
}

fn parse_en_passant(s: String) -> Result(Option(Square), FenError) {
  case s {
    "-" -> Ok(None)
    _ ->
      case square.from_string(s) {
        Ok(sq) -> Ok(Some(sq))
        Error(_) -> Error(InvalidEnPassant(s))
      }
  }
}

fn parse_halfmove_clock(s: String) -> Result(Int, FenError) {
  case int.parse(s) {
    Ok(n) -> Ok(n)
    Error(_) -> Error(InvalidHalfmoveClock(s))
  }
}

fn parse_fullmove_number(s: String) -> Result(Int, FenError) {
  case int.parse(s) {
    Ok(n) -> Ok(n)
    Error(_) -> Error(InvalidFullmoveNumber(s))
  }
}

fn board_to_string(board: Board) -> String {
  [7, 6, 5, 4, 3, 2, 1, 0]
  |> list.map(fn(rank_idx) { rank_to_fen(board, rank_idx) })
  |> string.join("/")
}

fn rank_to_fen(board: Board, rank_idx: Int) -> String {
  let assert Ok(rank) = square.rank_from_int(rank_idx)
  rank_to_fen_loop(board, rank, 0, 0, "")
}

fn rank_to_fen_loop(
  board: Board,
  rank: square.Rank,
  file_idx: Int,
  empty_count: Int,
  acc: String,
) -> String {
  case file_idx {
    8 ->
      case empty_count {
        0 -> acc
        n -> acc <> int.to_string(n)
      }
    _ -> {
      let assert Ok(file) = square.file_from_int(file_idx)
      let sq = Square(file, rank)
      case dict.get(board.pieces, sq) {
        Ok(colored_piece) -> {
          let prefix = case empty_count {
            0 -> acc
            n -> acc <> int.to_string(n)
          }
          rank_to_fen_loop(
            board,
            rank,
            file_idx + 1,
            0,
            prefix <> piece.to_fen_char(colored_piece),
          )
        }
        Error(_) ->
          rank_to_fen_loop(board, rank, file_idx + 1, empty_count + 1, acc)
      }
    }
  }
}

fn active_color_to_string(color: color.Color) -> String {
  case color {
    White -> "w"
    Black -> "b"
  }
}

fn castling_to_string(castling: CastlingRights) -> String {
  let s =
    ""
    |> fn(s) {
      case castling.white_kingside {
        True -> s <> "K"
        False -> s
      }
    }
    |> fn(s) {
      case castling.white_queenside {
        True -> s <> "Q"
        False -> s
      }
    }
    |> fn(s) {
      case castling.black_kingside {
        True -> s <> "k"
        False -> s
      }
    }
    |> fn(s) {
      case castling.black_queenside {
        True -> s <> "q"
        False -> s
      }
    }
  case s {
    "" -> "-"
    _ -> s
  }
}

fn en_passant_to_string(ep: Option(Square)) -> String {
  case ep {
    None -> "-"
    Some(sq) -> square.to_string(sq)
  }
}
