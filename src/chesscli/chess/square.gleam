import gleam/result
import gleam/string

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

pub type Square {
  Square(file: File, rank: Rank)
}

pub fn to_string(sq: Square) -> String {
  file_to_string(sq.file) <> rank_to_string(sq.rank)
}

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

pub fn to_index(sq: Square) -> Int {
  rank_to_int(sq.rank) * 8 + file_to_int(sq.file)
}

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

fn file_to_string(file: File) -> String {
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

fn rank_to_string(rank: Rank) -> String {
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
