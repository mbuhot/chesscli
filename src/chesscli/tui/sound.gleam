//// Plays short audio cues when chess moves occur, giving tactile
//// feedback similar to online chess platforms.

import chesscli/chess/board
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
/// and what sound to play for it. Always plays the sound for the move
/// the cursor lands on (current_index - 1), regardless of direction.
pub fn determine_sound(old: AppState, new: AppState) -> Option(SoundType) {
  case old.game.current_index == new.game.current_index {
    True -> None
    False -> sound_for_move_at(new, new.game.current_index - 1)
  }
}

/// Determine the sound for the move at the given index.
/// Examines the move itself and the resulting position (index + 1).
fn sound_for_move_at(state: AppState, move_idx: Int) -> Option(SoundType) {
  case list_at(state.game.moves, move_idx) {
    None -> None
    Some(m) -> {
      // Check if the position AFTER the move has the side-to-move in check
      case list_at(state.game.positions, move_idx + 1) {
        None -> Some(MoveSound)
        Some(pos_after) ->
          case move_gen.is_in_check(pos_after, pos_after.active_color) {
            True -> Some(CheckSound)
            False ->
              case m.is_castling {
                True -> Some(CastleSound)
                False -> {
                  // Was there a capture? Check the position BEFORE the move
                  case list_at(state.game.positions, move_idx) {
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
}

fn list_at(lst: List(a), index: Int) -> Option(a) {
  case lst, index {
    [], _ -> None
    [head, ..], 0 -> Some(head)
    [_, ..tail], n if n > 0 -> list_at(tail, n - 1)
    _, _ -> None
  }
}
