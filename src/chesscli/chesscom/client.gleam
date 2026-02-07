//// Thin HTTP client for chess.com API endpoints.
//// Wraps gleam_fetch with JSON decoding via api.gleam decoders.

import chesscli/chesscom/api.{
  type ApiError, type ArchivesResponse, type GamesResponse, HttpError, JsonError,
}
import gleam/dynamic/decode
import gleam/fetch
import gleam/http/request
import gleam/javascript/promise.{type Promise}

/// Fetch the list of monthly archive URLs for a player.
pub fn fetch_archives(
  username: String,
) -> Promise(Result(ArchivesResponse, ApiError)) {
  let url = api.archives_url(username)
  fetch_and_decode(url, api.archives_decoder())
}

/// Fetch all games from a specific monthly archive URL.
pub fn fetch_games(archive_url: String) -> Promise(Result(GamesResponse, ApiError)) {
  fetch_and_decode(archive_url, api.games_decoder())
}

fn fetch_and_decode(
  url: String,
  decoder: decode.Decoder(a),
) -> Promise(Result(a, ApiError)) {
  let assert Ok(req) = request.to(url)
  fetch.send(req)
  |> promise.try_await(fn(resp) { fetch.read_json_body(resp) })
  |> promise.map(fn(result) {
    case result {
      Ok(resp) ->
        case decode.run(resp.body, decoder) {
          Ok(data) -> Ok(data)
          Error(_) -> Error(JsonError("Failed to decode response"))
        }
      Error(fetch.NetworkError(msg)) -> Error(HttpError(msg))
      Error(fetch.InvalidJsonBody) -> Error(JsonError("Invalid JSON body"))
      Error(fetch.UnableToReadBody) ->
        Error(HttpError("Unable to read response body"))
    }
  })
}
