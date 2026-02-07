# Gleam Documentation

- every public module gets a `////` module doc comment explaining its role
- every public type and public function gets a `///` doc comment explaining WHY it exists, not restating the implementation
- don't document private functions, individual enum variants (unless non-obvious), or trivial constants (e.g. 64 square constants)
- keep doc comments concise — 1-2 lines typical

# Project Conventions

- use `square.e4` constants instead of `Square(E, R4)` — only use the `Square(file, rank)` constructor for dynamic construction
- don't duplicate utility functions across modules — make them public in the owning module (e.g. `square.file_to_string`, `square.rank_to_string`)
- NEVER add packages directly to gleam.toml — ALWAYS use `gleam add <package>` as it selects the newest compatible version
