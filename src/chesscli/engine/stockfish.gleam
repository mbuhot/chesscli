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

/// Send "quit" and kill the Stockfish process.
@external(javascript, "./stockfish_ffi.mjs", "stop")
pub fn stop(engine: EngineProcess) -> Nil
