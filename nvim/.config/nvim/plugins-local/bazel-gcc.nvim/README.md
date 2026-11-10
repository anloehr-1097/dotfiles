# bazel-gcc.nvim

Two-stage C/C++ diagnostics for Bazel workspaces built with GCC:

| Stage  | Tool   | Provides |
|--------|--------|----------|
| fast   | clangd | navigation, completion, hover, references, index, clang-tidy |
| truth  | Bazel + GCC | errors and warnings from the real compile (namespace `bazel-gcc`) |

clangd's clang frontend misreports some GCC extensions and libstdc++ code. GCC is the
compiler that actually builds the code, so its output is authoritative.

## How it works

* **On save** (debounced) it runs `bazel build` in the background for the rules that own the
  file (`same_pkg_direct_rdeps` query, cached until a BUILD file changes; falls back to
  `//pkg:all`). Flags: `--build_event_json_file --build_event_publish_all_actions --keep_going`.
* **BEP ingestion:** every executed action reports its command line and stderr file. GCC
  output (`file:line:col: severity: msg [-Wflag]`, caret ranges, folded notes) is parsed
  per action. Paths resolve from execroot/sandbox to workspace files, and GCC display
  columns convert to byte columns.
* **Cached actions keep their diagnostics.** Bazel never replays the output of a cached
  action, so diagnostics are stored per action and replaced only when that action runs
  again. The store is persisted in `stdpath("state")/bazel-gcc/`.
* **Bazel's own errors** (bad deps, analysis errors, failed links) are placed on the BUILD
  file line (source `bazel`).
* **compile_commands.json** comes from `bazel aquery 'mnemonic("CppCompile", deps(//...))'`.
  It has the exact GCC command lines, with GCC-only flags stripped. `external` and `bazel-out`
  symlinks are created so execroot-relative paths resolve. clangd is restarted when the
  database first appears. It regenerates when BUILD/.bzl/MODULE files are saved.
* **clangd filtering** (`clangd_diagnostics`): in Bazel workspaces only, clangd's
  clang-frontend diagnostics are dropped by default. clang-tidy and include-cleaner results
  stay.

clangd needs `--query-driver=**/*gcc*,**/*g++*` (set in `lua/andy/plugins/lsp.lua`) so it
asks GCC for its libstdc++ include paths.

## Commands

`:BazelGcc build [targets]`, `compdb [targets]`, `qf`, `log`, `clear`, `pin [targets]`,
`unpin`, `targets`, `toggle`, `info`. Health check: `:checkhealth bazel-gcc`.
Statusline: `require("bazel-gcc").status()`. Events: `User BazelGccBuildStart/BazelGccBuildDone`.

Keys (from the lazy spec): `<leader>Bb` build, `Bq` quickfix, `Bl` log, `Bc` compdb,
`Bp` pin, `Bt` toggle.

## Options

See `lua/bazel-gcc/config.lua`. Most relevant:

```lua
opts = {
  bazel_args = { "--config=gcc" },  -- same flags as your terminal builds (keeps analysis cache)
  startup_args = {},                -- e.g. { "--output_base=..." } for a separate server
  compile_only = false,             -- true: skip linking (faster, no linker errors)
  interrupt = false,                -- true: a save cancels the running build
  clangd_diagnostics = "tidy",      -- "all" | "hint" | "tidy" | "none"
}
```

## Limitations

* Warnings from files that were last compiled *outside* Neovim (and are cached) only appear
  after the file is next recompiled.
* Diagnostic positions refresh on the next build, not while you type.
* The plugin writes `compile_commands.json`, `external` (and `bazel-out` if missing) into the
  workspace root. Add them to `.gitignore`.

## Tests

```sh
nvim -l tests/parser_test.lua   # parser unit tests
tests/e2e.sh [dir]              # tiny Bazel+GCC project, drives your real config headless
```
