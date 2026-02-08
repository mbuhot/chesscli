import { readFileSync, writeFileSync, mkdirSync, existsSync } from "fs";
import { homedir } from "os";
import { Some, None } from "../../../gleam_stdlib/gleam/option.mjs";
import { toList } from "../../gleam.mjs";
import { Puzzle } from "./puzzle.mjs";
import { White, Black } from "../chess/color.mjs";
import {
  Best, Excellent, Good, Miss, Inaccuracy, Mistake, Blunder,
} from "../engine/analysis.mjs";

const DIR = homedir() + "/.chesscli";
const PATH = DIR + "/puzzles.json";

const classificationToString = (c) => {
  if (c instanceof Best) return "Best";
  if (c instanceof Excellent) return "Excellent";
  if (c instanceof Good) return "Good";
  if (c instanceof Miss) return "Miss";
  if (c instanceof Inaccuracy) return "Inaccuracy";
  if (c instanceof Mistake) return "Mistake";
  if (c instanceof Blunder) return "Blunder";
  return "Good";
};

const stringToClassification = (s) => {
  switch (s) {
    case "Best": return new Best();
    case "Excellent": return new Excellent();
    case "Good": return new Good();
    case "Miss": return new Miss();
    case "Inaccuracy": return new Inaccuracy();
    case "Mistake": return new Mistake();
    case "Blunder": return new Blunder();
    default: return new Good();
  }
};

const colorToString = (c) => c instanceof White ? "White" : "Black";
const stringToColor = (s) => s === "White" ? new White() : new Black();

function puzzleToJson(p) {
  return {
    fen: p.fen,
    player_color: colorToString(p.player_color),
    solution_uci: p.solution_uci,
    played_uci: p.played_uci,
    continuation: p.continuation.toArray(),
    eval_before: p.eval_before,
    eval_after: p.eval_after,
    source_label: p.source_label,
    classification: classificationToString(p.classification),
    white_name: p.white_name,
    black_name: p.black_name,
    solve_count: p.solve_count,
  };
}

function jsonToPuzzle(j) {
  return new Puzzle(
    j.fen,
    stringToColor(j.player_color),
    j.solution_uci,
    j.played_uci,
    toList(j.continuation || []),
    j.eval_before,
    j.eval_after,
    j.source_label,
    stringToClassification(j.classification),
    j.white_name || "?",
    j.black_name || "?",
    j.solve_count || 0,
  );
}

export function read_puzzles() {
  try {
    if (!existsSync(PATH)) return new None();
    const data = JSON.parse(readFileSync(PATH, "utf8"));
    if (!Array.isArray(data)) return new None();
    const puzzles = data.map(jsonToPuzzle);
    return new Some(toList(puzzles));
  } catch {
    return new None();
  }
}

export function write_puzzles(puzzles) {
  try {
    if (!existsSync(DIR)) mkdirSync(DIR, { recursive: true });
    const arr = puzzles.toArray().map(puzzleToJson);
    writeFileSync(PATH, JSON.stringify(arr, null, 2), "utf8");
  } catch {
    // Silently ignore write failures
  }
}
