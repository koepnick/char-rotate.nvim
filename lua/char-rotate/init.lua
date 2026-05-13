-- char-rotate.nvim
-- Rotate the character under the cursor through user-defined variants.

local M = {}

-- Default rotation groups. Each string is a cycle: pressing `~` on any
-- character in the string replaces it with the next one, wrapping around.
-- Users can override or extend this via setup({ rotations = { ... } }).
M.defaults = {
  rotations = {
    "aàáâãäåā",
    "AÀÁÂÃÄÅĀ",
    "eèéêëē",
    "EÈÉÊËĒ",
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
  },
  -- If true, when the character under the cursor isn't in any rotation,
  -- fall back to the built-in case-toggle behavior of `~`.
  fallback_to_case_toggle = true,
}

-- Internal lookup: character -> next character in its rotation.
local next_char = {}

-- Build the lookup table from a list of rotation strings.
-- We use vim.fn.split with empty separator + utf-8 awareness so that
-- multi-byte characters (é, ñ, etc.) are treated as single units.
local function build_lookup(rotations)
  next_char = {}
  for _, group in ipairs(rotations) do
    -- Split a UTF-8 string into a list of characters.
    local chars = vim.fn.split(group, "\\zs")
    local n = #chars
    if n > 1 then
      for i, ch in ipairs(chars) do
        local nxt = chars[(i % n) + 1]
        next_char[ch] = nxt
      end
    end
  end
end

-- Get the character under the cursor (UTF-8 aware) and its byte range
-- on the current line. Returns: char, line, col_start (0-indexed byte),
-- col_end_exclusive (0-indexed byte).
local function char_under_cursor()
  local row = vim.fn.line(".") - 1
  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
  local byte_col = vim.fn.col(".") - 1 -- 0-indexed byte position

  if byte_col >= #line then
    return nil
  end

  -- Find the start of the UTF-8 character at byte_col. In Neovim, the cursor
  -- always sits on the first byte of a multi-byte char in normal mode, so
  -- byte_col is already the start, but we compute the length to be safe.
  local b = line:byte(byte_col + 1)
  local len
  if b < 0x80 then len = 1
  elseif b < 0xC0 then
    -- Continuation byte; shouldn't happen in normal mode, but bail out.
    return nil
  elseif b < 0xE0 then len = 2
  elseif b < 0xF0 then len = 3
  else len = 4
  end

  local char = line:sub(byte_col + 1, byte_col + len)
  return char, row, byte_col, byte_col + len, line
end

-- The function bound to `~`. Handles a count too: `3~` rotates the next
-- three characters, like the built-in `~`.
function M.rotate()
  local count = vim.v.count1
  for _ = 1, count do
    local char, row, c_start, c_end, line = char_under_cursor()
    if not char then return end

    local replacement = next_char[char]

    if replacement then
      vim.api.nvim_buf_set_text(0, row, c_start, row, c_end, { replacement })
      -- Stay on the same character so the user can press `~` again to
      -- continue cycling. (The built-in `~` advances; we deliberately
      -- don't, since cycling through variants is the whole point.)
      vim.api.nvim_win_set_cursor(0, { row + 1, c_start })
    elseif M.config.fallback_to_case_toggle then
      -- Defer to Vim's built-in `~`. We pass a count of 1 because we're
      -- already inside our own count loop.
      vim.cmd("normal! ~")
    else
      -- No rotation and fallback disabled: just advance the cursor so a
      -- repeated press doesn't get stuck.
      vim.api.nvim_win_set_cursor(0, { row + 1, c_end })
    end
  end
end

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.defaults, opts)
  build_lookup(M.config.rotations)

  vim.keymap.set("n", "~", function() M.rotate() end, {
    desc = "Rotate character under cursor through configured variants",
  })
end

return M
