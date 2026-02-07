import chesscli/chess/color.{Black, White}

pub fn opposite_white_test() {
  assert color.opposite(White) == Black
}

pub fn opposite_black_test() {
  assert color.opposite(Black) == White
}

pub fn to_string_white_test() {
  assert color.to_string(White) == "White"
}

pub fn to_string_black_test() {
  assert color.to_string(Black) == "Black"
}
