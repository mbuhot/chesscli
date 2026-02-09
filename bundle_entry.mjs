// Bundle entry point for `bun build --compile`.
// Embeds sound files and sets them up before the app starts.
import move_mp3 from "./priv/sound/lisp/Move.mp3" with { type: "file" };
import capture_mp3 from "./priv/sound/lisp/Capture.mp3" with { type: "file" };
import check_mp3 from "./priv/sound/lisp/Check.mp3" with { type: "file" };
import { mkdtempSync, writeFileSync, readFileSync, existsSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";

// Extract embedded sounds to temp directory so afplay can read them.
// Bun's $bunfs virtual paths are not accessible to external processes.
try {
  const dir = mkdtempSync(join(tmpdir(), "chesscli-sounds-"));
  const extract = (bunfsPath, name) => {
    const realPath = join(dir, name);
    writeFileSync(realPath, readFileSync(bunfsPath));
    return realPath;
  };
  globalThis.__chesscli_sounds = {
    move: extract(move_mp3, "Move.mp3"),
    capture: extract(capture_mp3, "Capture.mp3"),
    check: extract(check_mp3, "Check.mp3"),
    castle: extract(move_mp3, "Move.mp3"),
  };
} catch (_) {
  // Sounds will silently fail if extraction fails
}

// Now import and run the app
import { main } from "./build/dev/javascript/chesscli/chesscli.mjs";
main();
