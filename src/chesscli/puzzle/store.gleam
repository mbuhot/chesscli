//// Persists puzzles to ~/.chesscli/puzzles.json for cross-session training.

import chesscli/puzzle/puzzle.{type Puzzle}
import gleam/option.{type Option}

/// Read cached puzzles from disk, or None if no cache exists.
@external(javascript, "./store_ffi.mjs", "read_puzzles")
pub fn read_puzzles() -> Option(List(Puzzle))

/// Write puzzles to the cache file, replacing any existing data.
@external(javascript, "./store_ffi.mjs", "write_puzzles")
pub fn write_puzzles(puzzles: List(Puzzle)) -> Nil
