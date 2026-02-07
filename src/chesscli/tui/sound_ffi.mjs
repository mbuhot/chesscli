import { spawn } from "bun";
import { join } from "path";

const soundDir = join(process.cwd(), "priv", "sound", "lisp");

const fileNames = {
  move: "Move.mp3",
  capture: "Capture.mp3",
  check: "Check.mp3",
  castle: "Move.mp3",
};

export function play_sound(type) {
  const file = fileNames[type] || fileNames.move;
  const path = join(soundDir, file);
  try {
    spawn(["afplay", path]);
  } catch (_) {
    // Silently ignore if afplay is not available
  }
}
