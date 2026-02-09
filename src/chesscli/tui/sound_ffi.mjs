import { spawn } from "bun";
import { join } from "path";
import { existsSync } from "fs";

// Sound paths are resolved lazily. In a compiled binary, the bundle
// entry point sets globalThis.__chesscli_sounds before main() runs.
// In development (gleam run), sounds are loaded from cwd/priv.
const devDir = join(process.cwd(), "priv", "sound", "lisp");

const soundNames = {
  move: "Move.mp3",
  capture: "Capture.mp3",
  check: "Check.mp3",
  castle: "Move.mp3",
};

let resolvedPaths = null;

function resolvePaths() {
  if (resolvedPaths) return resolvedPaths;

  // Check if bundle entry injected embedded sound paths
  if (globalThis.__chesscli_sounds) {
    resolvedPaths = globalThis.__chesscli_sounds;
    return resolvedPaths;
  }

  // Development: load from priv directory
  resolvedPaths = {};
  for (const [key, file] of Object.entries(soundNames)) {
    const path = join(devDir, file);
    if (existsSync(path)) {
      resolvedPaths[key] = path;
    }
  }
  return resolvedPaths;
}

export function play_sound(type) {
  try {
    const paths = resolvePaths();
    const path = paths[type] || paths.move;
    if (path) spawn(["afplay", path]);
  } catch (_) {
    // Silently ignore if afplay is not available
  }
}
