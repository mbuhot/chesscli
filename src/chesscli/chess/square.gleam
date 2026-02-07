//// Models the 64 squares of a chess board using typed file and rank values,
//// with conversions between algebraic notation (e.g. "e4"), integer indices
//// (0..63), and named constants for readable board setup code.

import gleam/result
import gleam/string

/// A column on the chess board, labeled a through h from the queenside.
pub type File {
  A
  B
  C
  D
  E
  F
  G
  H
}

/// A row on the chess board, numbered 1 through 8 from White's side.
pub type Rank {
  R1
  R2
  R3
  R4
  R5
  R6
  R7
  R8
}

/// A specific position on the board, identified by its file and rank.
pub type Square {
  Square(file: File, rank: Rank)
}

// Named constants for all 64 squares — use as square.e4 instead of Square(E, R4).
pub const a1 = Square(A, R1)
pub const a2 = Square(A, R2)
pub const a3 = Square(A, R3)
pub const a4 = Square(A, R4)
pub const a5 = Square(A, R5)
pub const a6 = Square(A, R6)
pub const a7 = Square(A, R7)
pub const a8 = Square(A, R8)
pub const b1 = Square(B, R1)
pub const b2 = Square(B, R2)
pub const b3 = Square(B, R3)
pub const b4 = Square(B, R4)
pub const b5 = Square(B, R5)
pub const b6 = Square(B, R6)
pub const b7 = Square(B, R7)
pub const b8 = Square(B, R8)
pub const c1 = Square(C, R1)
pub const c2 = Square(C, R2)
pub const c3 = Square(C, R3)
pub const c4 = Square(C, R4)
pub const c5 = Square(C, R5)
pub const c6 = Square(C, R6)
pub const c7 = Square(C, R7)
pub const c8 = Square(C, R8)
pub const d1 = Square(D, R1)
pub const d2 = Square(D, R2)
pub const d3 = Square(D, R3)
pub const d4 = Square(D, R4)
pub const d5 = Square(D, R5)
pub const d6 = Square(D, R6)
pub const d7 = Square(D, R7)
pub const d8 = Square(D, R8)
pub const e1 = Square(E, R1)
pub const e2 = Square(E, R2)
pub const e3 = Square(E, R3)
pub const e4 = Square(E, R4)
pub const e5 = Square(E, R5)
pub const e6 = Square(E, R6)
pub const e7 = Square(E, R7)
pub const e8 = Square(E, R8)
pub const f1 = Square(F, R1)
pub const f2 = Square(F, R2)
pub const f3 = Square(F, R3)
pub const f4 = Square(F, R4)
pub const f5 = Square(F, R5)
pub const f6 = Square(F, R6)
pub const f7 = Square(F, R7)
pub const f8 = Square(F, R8)
pub const g1 = Square(G, R1)
pub const g2 = Square(G, R2)
pub const g3 = Square(G, R3)
pub const g4 = Square(G, R4)
pub const g5 = Square(G, R5)
pub const g6 = Square(G, R6)
pub const g7 = Square(G, R7)
pub const g8 = Square(G, R8)
pub const h1 = Square(H, R1)
pub const h2 = Square(H, R2)
pub const h3 = Square(H, R3)
pub const h4 = Square(H, R4)
pub const h5 = Square(H, R5)
pub const h6 = Square(H, R6)
pub const h7 = Square(H, R7)
pub const h8 = Square(H, R8)

/// Converts to standard algebraic notation (e.g. "e4") for display and FEN output.
pub fn to_string(sq: Square) -> String {
  file_to_string(sq.file) <> rank_to_string(sq.rank)
}

/// Parses algebraic notation like "e4" into a Square, used when reading FEN or user input.
pub fn from_string(s: String) -> Result(Square, Nil) {
  case string.to_graphemes(s) {
    [f, r] -> {
      use file <- result.try(file_from_string(f))
      use rank <- result.try(rank_from_string(r))
      Ok(Square(file, rank))
    }
    _ -> Error(Nil)
  }
}

/// Maps a square to a 0..63 integer index (a1=0, h8=63) for array-style lookups.
pub fn to_index(sq: Square) -> Int {
  rank_to_int(sq.rank) * 8 + file_to_int(sq.file)
}

/// Converts a 0..63 index back to a Square, returning Error(Nil) if out of range.
pub fn from_index(i: Int) -> Result(Square, Nil) {
  case i >= 0 && i < 64 {
    True -> {
      use file <- result.try(file_from_int(i % 8))
      use rank <- result.try(rank_from_int(i / 8))
      Ok(Square(file, rank))
    }
    False -> Error(Nil)
  }
}

/// Returns the zero-based column index (A=0, H=7) for arithmetic on files.
pub fn file_to_int(file: File) -> Int {
  case file {
    A -> 0
    B -> 1
    C -> 2
    D -> 3
    E -> 4
    F -> 5
    G -> 6
    H -> 7
  }
}

/// Returns the zero-based row index (R1=0, R8=7) for arithmetic on ranks.
pub fn rank_to_int(rank: Rank) -> Int {
  case rank {
    R1 -> 0
    R2 -> 1
    R3 -> 2
    R4 -> 3
    R5 -> 4
    R6 -> 5
    R7 -> 6
    R8 -> 7
  }
}

/// Converts a column index back to a File, returning Error(Nil) if out of range.
pub fn file_from_int(i: Int) -> Result(File, Nil) {
  case i {
    0 -> Ok(A)
    1 -> Ok(B)
    2 -> Ok(C)
    3 -> Ok(D)
    4 -> Ok(E)
    5 -> Ok(F)
    6 -> Ok(G)
    7 -> Ok(H)
    _ -> Error(Nil)
  }
}

/// Converts a row index back to a Rank, returning Error(Nil) if out of range.
pub fn rank_from_int(i: Int) -> Result(Rank, Nil) {
  case i {
    0 -> Ok(R1)
    1 -> Ok(R2)
    2 -> Ok(R3)
    3 -> Ok(R4)
    4 -> Ok(R5)
    5 -> Ok(R6)
    6 -> Ok(R7)
    7 -> Ok(R8)
    _ -> Error(Nil)
  }
}

/// Returns the lowercase letter for a file, used in algebraic notation output.
pub fn file_to_string(file: File) -> String {
  case file {
    A -> "a"
    B -> "b"
    C -> "c"
    D -> "d"
    E -> "e"
    F -> "f"
    G -> "g"
    H -> "h"
  }
}

/// Returns the digit character for a rank, used in algebraic notation output.
pub fn rank_to_string(rank: Rank) -> String {
  case rank {
    R1 -> "1"
    R2 -> "2"
    R3 -> "3"
    R4 -> "4"
    R5 -> "5"
    R6 -> "6"
    R7 -> "7"
    R8 -> "8"
  }
}

fn file_from_string(s: String) -> Result(File, Nil) {
  case s {
    "a" -> Ok(A)
    "b" -> Ok(B)
    "c" -> Ok(C)
    "d" -> Ok(D)
    "e" -> Ok(E)
    "f" -> Ok(F)
    "g" -> Ok(G)
    "h" -> Ok(H)
    _ -> Error(Nil)
  }
}

fn rank_from_string(s: String) -> Result(Rank, Nil) {
  case s {
    "1" -> Ok(R1)
    "2" -> Ok(R2)
    "3" -> Ok(R3)
    "4" -> Ok(R4)
    "5" -> Ok(R5)
    "6" -> Ok(R6)
    "7" -> Ok(R7)
    "8" -> Ok(R8)
    _ -> Error(Nil)
  }
}
