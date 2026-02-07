//// Thin FFI wrapper for spawning and communicating with a Stockfish process.
//// Uses Bun.spawn via JavaScript interop — intentionally untested IO boundary.

import gleam/javascript/promise.{type Promise}

/// Opaque handle to a running Stockfish process.
pub type EngineProcess

/// Spawn Stockfish, send "uci"/"isready", and wait for readiness.
@external(javascript, "./stockfish_ffi.mjs", "start")
pub fn start() -> Promise(EngineProcess)

/// Send a position and "go depth N", collect all output lines until "bestmove".
@external(javascript, "./stockfish_ffi.mjs", "evaluate")
pub fn evaluate(
  engine: EngineProcess,
  fen: String,
  depth: Int,
) -> Promise(List(String))

/// Send "ucinewgame" + "isready" to reset the engine for a new game.
@external(javascript, "./stockfish_ffi.mjs", "new_game")
pub fn new_game(engine: EngineProcess) -> Promise(Nil)

/// Send a pre-formatted position command and "go depth N", collect output.
/// The position_cmd should be a complete UCI position string, e.g.
/// "position fen <fen> moves e2e4 e7e5".
@external(javascript, "./stockfish_ffi.mjs", "evaluate_incremental")
pub fn evaluate_incremental(
  engine: EngineProcess,
  position_cmd: String,
  depth: Int,
) -> Promise(List(String))

/// Send "quit" and kill the Stockfish process.
@external(javascript, "./stockfish_ffi.mjs", "stop")
pub fn stop(engine: EngineProcess) -> Nil
