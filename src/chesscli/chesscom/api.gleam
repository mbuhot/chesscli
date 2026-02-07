//// Chess.com public API types, JSON decoders, and display formatting.
//// Pure functions only — no HTTP. The client module handles network IO.

import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/string

/// Player info within a game summary from the chess.com API.
pub type PlayerInfo {
  PlayerInfo(username: String, rating: Int, result: String)
}

/// Summary of a single game from a chess.com monthly archive.
pub type GameSummary {
  GameSummary(
    url: String,
    pgn: String,
    time_control: String,
    time_class: String,
    end_time: Int,
    rated: Bool,
    white: PlayerInfo,
    black: PlayerInfo,
    accuracy_white: Float,
    accuracy_black: Float,
  )
}

/// Decoded response from the archives endpoint.
pub type ArchivesResponse {
  ArchivesResponse(archives: List(String))
}

/// Decoded response from the monthly games endpoint.
pub type GamesResponse {
  GamesResponse(games: List(GameSummary))
}

/// Errors from chess.com API interactions.
pub type ApiError {
  HttpError(String)
  JsonError(String)
}

/// Build the archives list URL for a given username.
pub fn archives_url(username: String) -> String {
  "https://api.chess.com/pub/player/"
  <> string.lowercase(username)
  <> "/games/archives"
}

/// Decoder for the archives endpoint JSON response.
pub fn archives_decoder() -> decode.Decoder(ArchivesResponse) {
  use archives <- decode.field("archives", decode.list(decode.string))
  decode.success(ArchivesResponse(archives:))
}

/// Decoder for the monthly games endpoint JSON response.
pub fn games_decoder() -> decode.Decoder(GamesResponse) {
  use games <- decode.field("games", decode.list(game_summary_decoder()))
  decode.success(GamesResponse(games:))
}

fn player_info_decoder() -> decode.Decoder(PlayerInfo) {
  use username <- decode.field("username", decode.string)
  use rating <- decode.field("rating", decode.int)
  use result <- decode.field("result", decode.string)
  decode.success(PlayerInfo(username:, rating:, result:))
}

fn game_summary_decoder() -> decode.Decoder(GameSummary) {
  use url <- decode.field("url", decode.string)
  use pgn <- decode.field("pgn", decode.string)
  use time_control <- decode.field("time_control", decode.string)
  use time_class <- decode.field("time_class", decode.string)
  use end_time <- decode.field("end_time", decode.int)
  use rated <- decode.field("rated", decode.bool)
  use white <- decode.field("white", player_info_decoder())
  use black <- decode.field("black", player_info_decoder())
  use accuracy_white <- decode.optional_field(
    "accuracies",
    0.0,
    decode.at(["white"], decode.float),
  )
  use accuracy_black <- decode.optional_field(
    "accuracies",
    0.0,
    decode.at(["black"], decode.float),
  )
  decode.success(GameSummary(
    url:,
    pgn:,
    time_control:,
    time_class:,
    end_time:,
    rated:,
    white:,
    black:,
    accuracy_white:,
    accuracy_black:,
  ))
}

/// Extract a human-readable label like "2024/01" from a full archive URL.
pub fn format_archive_label(url: String) -> String {
  let parts = string.split(url, "/")
  let reversed = list.reverse(parts)
  case reversed {
    [month, year, ..] -> year <> "/" <> month
    _ -> url
  }
}

/// Map a chess.com result string to a single-character symbol.
pub fn result_symbol(result: String) -> String {
  case result {
    "win" -> "W"
    "checkmated" | "timeout" | "resigned" | "abandoned" | "lose" -> "L"
    "agreed" | "stalemate" | "repetition" | "insufficient"
    | "50move"
    | "timevsinsufficient"
    -> "D"
    _ -> "?"
  }
}

/// Format a one-line summary of a game from the perspective of a given user.
pub fn format_game_line(game: GameSummary, username: String) -> String {
  let lower_username = string.lowercase(username)
  let #(player, opponent) = case
    string.lowercase(game.white.username) == lower_username
  {
    True -> #(game.white, game.black)
    False -> #(game.black, game.white)
  }
  let symbol = result_symbol(player.result)
  let rating = int.to_string(opponent.rating)
  let acc = case game.accuracy_white >. 0.0 || game.accuracy_black >. 0.0 {
    True -> {
      let player_acc = case
        string.lowercase(game.white.username) == lower_username
      {
        True -> game.accuracy_white
        False -> game.accuracy_black
      }
      " " <> float_to_string_1dp(player_acc) <> "%"
    }
    False -> ""
  }
  symbol
  <> " vs "
  <> opponent.username
  <> "("
  <> rating
  <> ") "
  <> game.time_class
  <> acc
}

fn float_to_string_1dp(f: Float) -> String {
  let rounded = float.round(f *. 10.0)
  let whole = rounded / 10
  let frac = case rounded % 10 {
    n if n < 0 -> -n
    n -> n
  }
  int.to_string(whole) <> "." <> int.to_string(frac)
}
