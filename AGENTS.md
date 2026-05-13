# AGENTS.md

Guidance for AI coding assistants working on `char-rotate.nvim`. Humans
are welcome to read this too — it doubles as a quick orientation.

## What this project is

A small Neovim plugin that remaps `~` in normal mode to cycle the
character under the cursor through user-defined rotation groups (e.g.
`e → è → é → ê → ë → ē → e`). Falls back to the built-in case-toggle
when the character isn't in any configured rotation.

Scope is deliberately small. Resist the urge to add features unless
asked — accretion is how small plugins become bad plugins.

## Repository layout

```
char-rotate.nvim/
├── lua/
│   └── char-rotate/
│       └── init.lua        -- the module; require("char-rotate")
├── plugin/
│   └── char-rotate.lua     -- auto-loads with defaults on startup
├── README.md
└── AGENTS.md               -- you are here
```

The directory name under `lua/` (`char-rotate`) **must** match the
string passed to `require(...)`. Neovim's Lua loader resolves modules
via `package.path` entries like `<rtp>/lua/?/init.lua`, so renaming one
without the other will produce `module 'char-rotate' not found`.

## Conventions

- **Lua style**: 2-space indentation, `snake_case` for locals and
  functions, `M` for the returned module table. Match the existing
  file rather than introducing a new style.
- **Comments**: explain *why*, not *what*. The existing comments flag
  non-obvious decisions (UTF-8 handling, cursor non-advancement); new
  comments should do the same.
- **No external dependencies.** This plugin uses only `vim.api`,
  `vim.fn`, and standard Lua. Don't pull in `plenary` or anything
  similar without a strong reason.
- **Public surface**: `setup(opts)` and `rotate()` on the module table.
  Everything else is internal — prefix with `local` and keep it out of
  `M`.

## Design decisions worth knowing

These are easy to "fix" by mistake. Don't, unless the user explicitly
asks for the opposite behavior.

1. **The cursor stays on the rotated character.** The built-in `~`
   advances; this plugin doesn't, because cycling a single character
   through variants is the whole point. A count like `3~` therefore
   means "jump 3 steps into the rotation," not "rotate the next 3
   characters."
2. **Fallback to `normal! ~` is on by default.** If the character isn't
   in any rotation, users still get case-toggle behavior — so the
   plugin is strictly additive and never makes `~` *worse*. The
   `fallback_to_case_toggle` option lets users opt out.
3. **UTF-8 is handled explicitly.** Rotation strings are split with
   `vim.fn.split(s, "\\zs")` so multi-byte characters stay intact, and
   the character under the cursor is read by inspecting the leading
   byte to compute UTF-8 length. Don't replace this with naive byte
   indexing.
4. **Defaults are conservative.** The default rotations cover Latin
   accented characters because that's the canonical use case. Don't
   add emoji cycles, bracket pairs, or other novelty rotations to the
   defaults — those belong in user config, as shown in the README.

## Testing

There's no test runner wired up. For ad-hoc verification:

```bash
nvim --headless -u NONE -l test_plugin.lua
```

The pattern (see chat history if a `test_plugin.lua` doesn't exist in
the repo): prepend the plugin directory to `runtimepath`, call
`setup()`, drive the buffer via `nvim_buf_set_lines` and
`nvim_win_set_cursor`, invoke `require("char-rotate").rotate()`, and
assert on the resulting buffer contents.

Cases worth covering when changing rotation logic:
- Single press on a known character.
- Multiple presses cycling through a rotation.
- Wrap-around at the end of a rotation.
- Multi-byte character under the cursor.
- Character not in any rotation, with and without `fallback_to_case_toggle`.
- Count prefix (`3~`).

If a real test framework gets added later, `mini.test` or `plenary`'s
busted harness are the conventional choices.

## Iteration loop

When developing interactively, reload without restarting Neovim:

```lua
for name, _ in pairs(package.loaded) do
  if name:match("^char%-rotate") then package.loaded[name] = nil end
end
require("char-rotate").setup()
```

Mapping that to `<leader>rr` during development is recommended.

## Things that went wrong before (and how to avoid them)

These bit a real human during initial development. Worth checking
first if something breaks:

- **`module 'char-rotate' not found`**: the file is at `lua/init.lua`
  instead of `lua/char-rotate/init.lua`. The `lua/` directory is a
  namespace, not a module.
- **`loop or previous error loading module 'char-rotate'`**: the
  module is `require`-ing itself somewhere near the top of `init.lua`.
  A module builds itself up as a local table and returns it — it
  should never `require` its own name.
- **`attempt to call method 'find' (a nil value)` in lazy.nvim**: the
  plugin spec is missing a source. Use `"user/repo"` for GitHub or
  `dir = "/path"` for a local checkout — not a bare module name.

## Out of scope

Things this plugin is intentionally *not*:

- A general-purpose keybinding framework.
- A typing-assistance / autocomplete tool.
- A replacement for digraph input (`<C-k>` in insert mode handles
  that natively and well).
- A multi-character or word-level rotator. The unit is one character.

If a request would push the plugin in any of these directions, flag it
and confirm before implementing.

## When in doubt

Read `lua/char-rotate/init.lua`. It's under 100 lines; the whole
mental model fits in your head at once. Don't generate code that
duplicates logic already there, and don't refactor the existing code
unless asked.
