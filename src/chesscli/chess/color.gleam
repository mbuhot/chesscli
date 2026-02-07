pub type Color {
  White
  Black
}

pub fn opposite(color: Color) -> Color {
  case color {
    White -> Black
    Black -> White
  }
}

pub fn to_string(color: Color) -> String {
  case color {
    White -> "White"
    Black -> "Black"
  }
}
