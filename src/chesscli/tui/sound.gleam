//// Plays short audio cues when chess moves occur, giving tactile
//// feedback similar to online chess platforms.

import chesscli/chess/board
import chesscli/chess/game
import chesscli/chess/move_gen
import chesscli/tui/app.{type AppState}
import gleam/option.{type Option, None, Some}

/// Distinguishes the type of move so each gets a distinct sound.
pub type SoundType {
  MoveSound
  CaptureSound
  CheckSound
  CastleSound
}

@external(javascript, "./sound_ffi.mjs", "play_sound")
fn do_play(sound_name: String) -> Nil

/// Play the audio cue for a given sound type.
pub fn play(sound: SoundType) -> Nil {
  case sound {
    MoveSound -> do_play("move")
    CaptureSound -> do_play("capture")
    CheckSound -> do_play("check")
    CastleSound -> do_play("castle")
  }
}

/// Compare old and new app states to determine if a move occurred
/// and what sound to play for it.
pub fn determine_sound(old: AppState, new: AppState) -> Option(SoundType) {
  let old_idx = old.game.current_index
  let new_idx = new.game.current_index
  case old_idx == new_idx {
    True -> None
    False -> {
      case new_idx > old_idx {
        True -> sound_for_forward(new)
        False -> Some(MoveSound)
      }
    }
  }
}

/// Determine the sound type when navigating forward (the move at new_idx - 1
/// was just "played"). Priority: check > castle > capture > move.
fn sound_for_forward(state: AppState) -> Option(SoundType) {
  let move_idx = state.game.current_index - 1
  case list_at(state.game.moves, move_idx) {
    None -> None
    Some(m) -> {
      // Check if the resulting position has the side-to-move in check
      let pos = game.current_position(state.game)
      case move_gen.is_in_check(pos, pos.active_color) {
        True -> Some(CheckSound)
        False ->
          case m.is_castling {
            True -> Some(CastleSound)
            False -> {
              // Was there a capture? Check the position BEFORE the move
              let prev_idx = state.game.current_index - 1
              case list_at(state.game.positions, prev_idx) {
                Some(prev_pos) ->
                  case board.get(prev_pos.board, m.to) {
                    Some(_) -> Some(CaptureSound)
                    None ->
                      case m.is_en_passant {
                        True -> Some(CaptureSound)
                        False -> Some(MoveSound)
                      }
                  }
                None -> Some(MoveSound)
              }
            }
          }
      }
    }
  }
}

fn list_at(lst: List(a), index: Int) -> Option(a) {
  case lst, index {
    [], _ -> None
    [head, ..], 0 -> Some(head)
    [_, ..tail], n if n > 0 -> list_at(tail, n - 1)
    _, _ -> None
  }
}
