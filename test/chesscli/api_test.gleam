import chesscli/chesscom/api
import gleam/json

// --- archives_url ---

pub fn archives_url_lowercases_username_test() {
  assert api.archives_url("Hikaru")
    == "https://api.chess.com/pub/player/hikaru/games/archives"
}

// --- format_archive_label ---

pub fn format_archive_label_extracts_year_month_test() {
  assert api.format_archive_label(
      "https://api.chess.com/pub/player/hikaru/games/2024/01",
    )
    == "2024/01"
}

pub fn format_archive_label_different_month_test() {
  assert api.format_archive_label(
      "https://api.chess.com/pub/player/someone/games/2023/12",
    )
    == "2023/12"
}

// --- result_symbol ---

pub fn result_symbol_win_test() {
  assert api.result_symbol("win") == "W"
}

pub fn result_symbol_loss_variants_test() {
  assert api.result_symbol("checkmated") == "L"
  assert api.result_symbol("timeout") == "L"
  assert api.result_symbol("resigned") == "L"
  assert api.result_symbol("abandoned") == "L"
}

pub fn result_symbol_draw_variants_test() {
  assert api.result_symbol("agreed") == "D"
  assert api.result_symbol("stalemate") == "D"
  assert api.result_symbol("repetition") == "D"
  assert api.result_symbol("insufficient") == "D"
  assert api.result_symbol("50move") == "D"
  assert api.result_symbol("timevsinsufficient") == "D"
}

pub fn result_symbol_unknown_test() {
  assert api.result_symbol("something_else") == "?"
}

// --- decode_archives ---

pub fn decode_archives_test() {
  let json_str =
    "{\"archives\":[\"https://api.chess.com/pub/player/hikaru/games/2024/01\",\"https://api.chess.com/pub/player/hikaru/games/2024/02\"]}"
  let assert Ok(result) = json.parse(json_str, api.archives_decoder())
  assert result.archives == [
    "https://api.chess.com/pub/player/hikaru/games/2024/01",
    "https://api.chess.com/pub/player/hikaru/games/2024/02",
  ]
}

pub fn decode_archives_empty_test() {
  let json_str = "{\"archives\":[]}"
  let assert Ok(result) = json.parse(json_str, api.archives_decoder())
  assert result.archives == []
}

// --- decode_games ---

pub fn decode_games_test() {
  let json_str =
    "{\"games\":[{\"url\":\"https://chess.com/game/123\",\"pgn\":\"1. e4 e5\",\"time_control\":\"180\",\"time_class\":\"blitz\",\"end_time\":1700000000,\"rated\":true,\"white\":{\"username\":\"hikaru\",\"rating\":2900,\"result\":\"win\"},\"black\":{\"username\":\"opponent\",\"rating\":2700,\"result\":\"checkmated\"}}]}"
  let assert Ok(result) = json.parse(json_str, api.games_decoder())
  let assert [game] = result.games
  assert game.url == "https://chess.com/game/123"
  assert game.pgn == "1. e4 e5"
  assert game.time_class == "blitz"
  assert game.rated == True
  assert game.white.username == "hikaru"
  assert game.white.rating == 2900
  assert game.white.result == "win"
  assert game.black.username == "opponent"
  assert game.black.rating == 2700
  assert game.accuracy_white == 0.0
  assert game.accuracy_black == 0.0
}

pub fn decode_games_with_accuracy_test() {
  let json_str =
    "{\"games\":[{\"url\":\"https://chess.com/game/456\",\"pgn\":\"1. d4\",\"time_control\":\"600\",\"time_class\":\"rapid\",\"end_time\":1700000000,\"rated\":false,\"white\":{\"username\":\"a\",\"rating\":1500,\"result\":\"win\"},\"black\":{\"username\":\"b\",\"rating\":1400,\"result\":\"resigned\"},\"accuracies\":{\"white\":92.5,\"black\":85.3}}]}"
  let assert Ok(result) = json.parse(json_str, api.games_decoder())
  let assert [game] = result.games
  assert game.accuracy_white == 92.5
  assert game.accuracy_black == 85.3
}

// --- format_game_line ---

pub fn format_game_line_as_white_test() {
  let game =
    api.GameSummary(
      url: "",
      pgn: "",
      time_control: "180",
      time_class: "blitz",
      end_time: 0,
      rated: True,
      white: api.PlayerInfo("hikaru", 2900, "win"),
      black: api.PlayerInfo("opponent", 2700, "checkmated"),
      accuracy_white: 0.0,
      accuracy_black: 0.0,
    )
  assert api.format_game_line(game, "hikaru") == "W vs opponent(2700) blitz"
}

pub fn format_game_line_as_black_with_accuracy_test() {
  let game =
    api.GameSummary(
      url: "",
      pgn: "",
      time_control: "600",
      time_class: "rapid",
      end_time: 0,
      rated: True,
      white: api.PlayerInfo("opponent", 2000, "win"),
      black: api.PlayerInfo("hikaru", 2100, "resigned"),
      accuracy_white: 90.0,
      accuracy_black: 85.5,
    )
  assert api.format_game_line(game, "hikaru")
    == "L vs opponent(2000) rapid 85.5%"
}
