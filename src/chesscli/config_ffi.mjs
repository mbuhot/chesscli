import { readFileSync, writeFileSync, existsSync } from "fs";
import { homedir } from "os";
import { Some, None } from "../../gleam_stdlib/gleam/option.mjs";

const CONFIG_PATH = homedir() + "/.chesscli.json";

export function read_username() {
  try {
    if (!existsSync(CONFIG_PATH)) return new None();
    const data = JSON.parse(readFileSync(CONFIG_PATH, "utf8"));
    return data.username ? new Some(data.username) : new None();
  } catch {
    return new None();
  }
}

export function write_username(username) {
  try {
    writeFileSync(CONFIG_PATH, JSON.stringify({ username }), "utf8");
  } catch {
    // Silently ignore write failures
  }
}
