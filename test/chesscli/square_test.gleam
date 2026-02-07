import chesscli/chess/square.{A, B, C, D, E, F, G, H, R1, R2, R3, R4, R5, R6, R7, R8, Square}

pub fn to_string_e4_test() {
  assert square.to_string(Square(E, R4)) == "e4"
}

pub fn to_string_a1_test() {
  assert square.to_string(Square(A, R1)) == "a1"
}

pub fn to_string_h8_test() {
  assert square.to_string(Square(H, R8)) == "h8"
}

pub fn from_string_e4_test() {
  assert square.from_string("e4") == Ok(Square(E, R4))
}

pub fn from_string_a1_test() {
  assert square.from_string("a1") == Ok(Square(A, R1))
}

pub fn from_string_h8_test() {
  assert square.from_string("h8") == Ok(Square(H, R8))
}

pub fn from_string_invalid_test() {
  assert square.from_string("i1") == Error(Nil)
  assert square.from_string("a9") == Error(Nil)
  assert square.from_string("") == Error(Nil)
  assert square.from_string("a") == Error(Nil)
}

pub fn to_index_a1_test() {
  assert square.to_index(Square(A, R1)) == 0
}

pub fn to_index_b1_test() {
  assert square.to_index(Square(B, R1)) == 1
}

pub fn to_index_h1_test() {
  assert square.to_index(Square(H, R1)) == 7
}

pub fn to_index_a2_test() {
  assert square.to_index(Square(A, R2)) == 8
}

pub fn to_index_h8_test() {
  assert square.to_index(Square(H, R8)) == 63
}

pub fn from_index_0_test() {
  assert square.from_index(0) == Ok(Square(A, R1))
}

pub fn from_index_63_test() {
  assert square.from_index(63) == Ok(Square(H, R8))
}

pub fn from_index_invalid_test() {
  assert square.from_index(-1) == Error(Nil)
  assert square.from_index(64) == Error(Nil)
}

pub fn roundtrip_string_test() {
  assert square.from_string("d7") == Ok(Square(D, R7))
  let assert Ok(sq) = square.from_string("d7")
  assert square.to_string(sq) == "d7"
}

pub fn roundtrip_index_test() {
  // a1=0, b1=1, ..., a2=8, ...
  let assert Ok(sq) = square.from_index(27)
  assert square.to_index(sq) == 27
}

pub fn file_to_int_test() {
  assert square.file_to_int(A) == 0
  assert square.file_to_int(H) == 7
}

pub fn rank_to_int_test() {
  assert square.rank_to_int(R1) == 0
  assert square.rank_to_int(R8) == 7
}

pub fn all_files_test() {
  assert square.file_to_int(A) == 0
  assert square.file_to_int(B) == 1
  assert square.file_to_int(C) == 2
  assert square.file_to_int(D) == 3
  assert square.file_to_int(E) == 4
  assert square.file_to_int(F) == 5
  assert square.file_to_int(G) == 6
  assert square.file_to_int(H) == 7
}

pub fn all_ranks_test() {
  assert square.rank_to_int(R1) == 0
  assert square.rank_to_int(R2) == 1
  assert square.rank_to_int(R3) == 2
  assert square.rank_to_int(R4) == 3
  assert square.rank_to_int(R5) == 4
  assert square.rank_to_int(R6) == 5
  assert square.rank_to_int(R7) == 6
  assert square.rank_to_int(R8) == 7
}
