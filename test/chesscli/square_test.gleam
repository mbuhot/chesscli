import chesscli/chess/square

pub fn to_string_e4_test() {
  assert square.to_string(square.e4) == "e4"
}

pub fn to_string_a1_test() {
  assert square.to_string(square.a1) == "a1"
}

pub fn to_string_h8_test() {
  assert square.to_string(square.h8) == "h8"
}

pub fn from_string_e4_test() {
  assert square.from_string("e4") == Ok(square.e4)
}

pub fn from_string_a1_test() {
  assert square.from_string("a1") == Ok(square.a1)
}

pub fn from_string_h8_test() {
  assert square.from_string("h8") == Ok(square.h8)
}

pub fn from_string_invalid_test() {
  assert square.from_string("i1") == Error(Nil)
  assert square.from_string("a9") == Error(Nil)
  assert square.from_string("") == Error(Nil)
  assert square.from_string("a") == Error(Nil)
}

pub fn to_index_a1_test() {
  assert square.to_index(square.a1) == 0
}

pub fn to_index_b1_test() {
  assert square.to_index(square.b1) == 1
}

pub fn to_index_h1_test() {
  assert square.to_index(square.h1) == 7
}

pub fn to_index_a2_test() {
  assert square.to_index(square.a2) == 8
}

pub fn to_index_h8_test() {
  assert square.to_index(square.h8) == 63
}

pub fn from_index_0_test() {
  assert square.from_index(0) == Ok(square.a1)
}

pub fn from_index_63_test() {
  assert square.from_index(63) == Ok(square.h8)
}

pub fn from_index_invalid_test() {
  assert square.from_index(-1) == Error(Nil)
  assert square.from_index(64) == Error(Nil)
}

pub fn roundtrip_string_test() {
  assert square.from_string("d7") == Ok(square.d7)
  let assert Ok(sq) = square.from_string("d7")
  assert square.to_string(sq) == "d7"
}

pub fn roundtrip_index_test() {
  // a1=0, b1=1, ..., a2=8, ...
  let assert Ok(sq) = square.from_index(27)
  assert square.to_index(sq) == 27
}

pub fn file_to_int_test() {
  assert square.file_to_int(square.A) == 0
  assert square.file_to_int(square.H) == 7
}

pub fn rank_to_int_test() {
  assert square.rank_to_int(square.R1) == 0
  assert square.rank_to_int(square.R8) == 7
}

pub fn all_files_test() {
  assert square.file_to_int(square.A) == 0
  assert square.file_to_int(square.B) == 1
  assert square.file_to_int(square.C) == 2
  assert square.file_to_int(square.D) == 3
  assert square.file_to_int(square.E) == 4
  assert square.file_to_int(square.F) == 5
  assert square.file_to_int(square.G) == 6
  assert square.file_to_int(square.H) == 7
}

pub fn all_ranks_test() {
  assert square.rank_to_int(square.R1) == 0
  assert square.rank_to_int(square.R2) == 1
  assert square.rank_to_int(square.R3) == 2
  assert square.rank_to_int(square.R4) == 3
  assert square.rank_to_int(square.R5) == 4
  assert square.rank_to_int(square.R6) == 5
  assert square.rank_to_int(square.R7) == 6
  assert square.rank_to_int(square.R8) == 7
}
