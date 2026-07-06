# char-rotate.nvim

A small Neovim plugin that turns `~` from a case-toggle into a
**character rotator**. Press `~` on a character and it cycles through
user-defined variants (e.g. `e → è → é → ê → ë → ē → e`).

If the character under the cursor isn't part of any configured rotation,
the plugin falls back to the normal case-toggle behavior, so you lose
nothing.

## Note

This is my first publicly published Neovim plugin. There may be anti-patterns
or non idiomatic methods. 

## Install

With **lazy.nvim** from GitHub:

```lua
{ "koepnick/char-rotate", opts = {} }
```
For local development, point lazy at your checkout:

```lua
{
  dir = "~/path/to/char-rotate.nvim",
  name = "char-rotate",
  opts = {},
}
```

With **packer.nvim**:

```lua
use {
  "koepnick/char-rotate",
  config = function() require("char-rotate").setup() end,
}
```

Or drop `lua/char-rotate/init.lua` and `plugin/char-rotate.lua` into
your config under the matching paths.

## Configuration

```lua
require("char-rotate").setup({
  -- Each string is a cycle. Pressing `key` on any character replaces it
  -- with the next character in the string, wrapping around at the end.
  rotations = {
    "aàáâãäåā",
    "AÀÁÂÃÄÅĀ",
    "eèéêëē",
    "EÈÉÊËĒ",
    -- ... add your own
    "-_",          -- toggle between hyphen and underscore
    "<>",          -- swap angle brackets
    "()[]{}",      -- rotate through bracket pairs
  },
  -- The key bound to the rotation in normal mode. Defaults to "~" to
  -- preserve compatibility and enable fallback to the built-in case-toggle.
  key = "~",
  fallback_to_case_toggle = true,
  -- If true (default), user-provided rotations are appended to the
  -- built-in defaults. Set to false to replace the defaults entirely.
  append_rotations = true,
})
```

**Note:** The `fallback_to_case_toggle` option only works when `key` is set to `"~"`, since it defers to Vim's built-in `~` command. If you use a different key, set `fallback_to_case_toggle = false`.

**Adding custom rotations:**

To add new rotations while keeping all built-in defaults, simply include the
`rotations` key — the new entries are appended to the defaults:

```lua
require("char-rotate").setup({
  rotations = {
    "-_",          -- custom: hyphen ↔ underscore
    "<>",          -- custom: angle brackets
  },
})
```

To replace the defaults entirely, set `append_rotations = false`:

```lua
require("char-rotate").setup({
  rotations = {
    "eèéêëē",
    "EÈÉÊËĒ",
    "-_",
  },
  append_rotations = false,
})
```

To remove specific built-in rotations, use `append_rotations = false` and
list only the rotations you want:

```lua
require("char-rotate").setup({
  -- Start with defaults, exclude the ones you don't want
  rotations = {
    "aàáâãäåā",
    "AÀÁÂÃÄÅĀ",
    "iìíîïī",
    "IÌÍÎÏĪ",
    "oòóôõöøō",
    "OÒÓÔÕÖØŌ",
    "uùúûüū",
    "UÙÚÛÜŪ",
    "cçćč",
    "CÇĆČ",
    "nñń",
    "NÑŃ",
    "sśš",
    "SŚŠ",
    "$£€",
    "%°",
    "0⁰₀",
    "1¹₁",
    "2²₂",
    "3³₃",
    "4⁴₄",
    "5⁵₅",
    "6⁶₆",
    "7⁷₇",
    "8⁸₈",
    "9⁹₉",
    "-–—",
    -- Exclude: "eèéêëē", "EÈÉÊËĒ", "$£€", "%°"
  },
  append_rotations = false,
})
```

Counts apply to the **same character**: `3~` on an `e` jumps three steps
into its rotation in one keystroke. (This differs from the built-in `~`,
which advances the cursor — but since the point of this plugin is to
cycle a single character through variants, staying put is more useful.)

## How it works

The plugin builds a `char → next_char` lookup from the rotation strings,
then maps `~` in normal mode to a Lua function that:

1. Reads the UTF-8 character under the cursor.
2. Replaces it with the next character in its rotation, if any.
3. Otherwise, falls back to `normal! ~` (case toggle).

## Layout

```
char-rotate.nvim/
├── lua/
│   └── char-rotate/
│       └── init.lua        -- module: require("char-rotate")
├── plugin/
│   └── char-rotate.lua     -- auto-loads with defaults
└── README.md
```

The module path `char-rotate` must match the directory name under `lua/`
exactly; Neovim's Lua loader resolves `require("char-rotate")` to
`lua/char-rotate/init.lua` via the runtimepath.

# TODO
- [ ] Turkish diacritics
- [x] Allow users to append custom lists rather than clobber
- [x] Allow re-mapping "~" to another key
