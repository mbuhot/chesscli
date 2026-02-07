import { toList } from "../../gleam.mjs";

class StockfishEngine {
  constructor(proc) {
    this.proc = proc;
    this.buffer = "";
    this.resolvers = [];
    this.lines = [];

    this._readLoop();
  }

  async _readLoop() {
    const reader = this.proc.stdout.getReader();
    const decoder = new TextDecoder();
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        this.buffer += decoder.decode(value, { stream: true });
        const parts = this.buffer.split("\n");
        this.buffer = parts.pop();
        for (const line of parts) {
          const trimmed = line.trim();
          if (trimmed === "") continue;
          this.lines.push(trimmed);
          if (this.resolvers.length > 0) {
            const { test, resolve } = this.resolvers[0];
            if (test(trimmed)) {
              this.resolvers.shift();
              resolve(this.lines.splice(0));
            }
          }
        }
      }
    } catch {
      // Process ended
    }
  }

  _send(cmd) {
    this.proc.stdin.write(cmd + "\n");
  }

  _waitFor(test) {
    return new Promise((resolve) => {
      // Check if already in buffer
      for (let i = 0; i < this.lines.length; i++) {
        if (test(this.lines[i])) {
          resolve(this.lines.splice(0, i + 1));
          return;
        }
      }
      this.resolvers.push({ test, resolve });
    });
  }
}

export async function start() {
  const proc = Bun.spawn(["stockfish"], {
    stdin: "pipe",
    stdout: "pipe",
    stderr: "pipe",
  });

  const engine = new StockfishEngine(proc);

  engine._send("uci");
  await engine._waitFor((line) => line === "uciok");
  engine.lines = [];

  engine._send("isready");
  await engine._waitFor((line) => line === "readyok");
  engine.lines = [];

  return engine;
}

export async function evaluate(engine, fen, depth) {
  engine.lines = [];
  engine._send("position fen " + fen);
  engine._send("go depth " + depth);

  const lines = await engine._waitFor((line) =>
    line.startsWith("bestmove")
  );

  return toList(lines);
}

export async function new_game(engine) {
  engine.lines = [];
  engine._send("ucinewgame");
  engine._send("isready");
  await engine._waitFor((line) => line === "readyok");
  engine.lines = [];
}

export async function evaluate_incremental(engine, position_cmd, depth) {
  engine.lines = [];
  engine._send(position_cmd);
  engine._send("go depth " + depth);

  const lines = await engine._waitFor((line) =>
    line.startsWith("bestmove")
  );

  return toList(lines);
}

export function stop(engine) {
  engine._send("quit");
  try {
    engine.proc.kill();
  } catch {
    // Already dead
  }
}
