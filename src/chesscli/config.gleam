//// Persists user preferences (chess.com username) to ~/.chesscli.json.

import gleam/option.{type Option}

/// Read the saved chess.com username, or None if not yet set.
@external(javascript, "./config_ffi.mjs", "read_username")
pub fn read_username() -> Option(String)

/// Save the chess.com username for future sessions.
@external(javascript, "./config_ffi.mjs", "write_username")
pub fn write_username(username: String) -> Nil
