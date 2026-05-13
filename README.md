# char-rotate.nvim

A small Neovim plugin that turns `~` from a case-toggle into a
**character rotator**. Press `~` on a character and it cycles through
user-defined variants (e.g. `e → è → é → ê → ë → ē → e`).

If the character under the cursor isn't part of any configured rotation,
the plugin falls back to the normal case-toggle behavior, so you lose
nothing.

## > [!NOTE]

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
  -- Each string is a cycle. Pressing `~` on any character replaces it
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
  fallback_to_case_toggle = true,
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

## Disclaimer

This project was developed with the assistance of a large language
model. The author reviewed, tested, and approved
the resulting code, but readers should be aware that LLM-generated
code can contain subtle bugs, outdated API usage, or design choices
that don't fit every use case. Treat it as you would any small
third-party plugin: read the source before running it, and file
issues if something misbehaves.
