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
  },
  -- If true, when the character under the cursor isn't in any rotation,
  -- fall back to the built-in case-toggle behavior of `~`.
  fallback_to_case_toggle = true,
  -- Key to bind the rotation to in normal mode. Defaults to "~" which
  -- also enables fallback to the built-in case-toggle behavior.
  key = "~",
  -- If true, user-provided rotations are appended to the defaults
  -- instead of replacing them. If false, user rotations completely
  -- replace the defaults.
  append_rotations = true,
}

-- Internal lookup: character -> next character in its rotation.
local next_char = {}

-- Public: returns the current lookup table (for testing)
function M._get_next_char()
  return next_char
end

-- Build the lookup table from a list of rotation strings.
-- We use vim.fn.split with empty separator + utf-8 awareness so that
-- multi-byte characters (é, ñ, etc.) are treated as single units.
-- After building the initial rotation, a case-toggle entry is inserted
-- after each lowercase character so that 'a' -> 'A' -> 'à' -> ... instead
-- of exhausting all lowercase variants before jumping to uppercase.
local function build_lookup(rotations)
  next_char = {}
  for _, group in ipairs(rotations) do
    local chars = vim.fn.split(group, "\\zs")
    local n = #chars
    if n > 1 then
      for i, ch in ipairs(chars) do
        local nxt = chars[(i % n) + 1]
        next_char[ch] = nxt
      end
    end
  end
  -- Insert case-toggle entries: for each lowercase ASCII letter that has
  -- both itself and its uppercase form in the lookup, insert the
  -- uppercase form immediately after the lowercase one in the cycle.
  -- This makes 'a' -> 'A' -> 'à' -> ... instead of exhausting all
  -- lowercase variants before jumping to uppercase.
  local lower_chars = {}
  for ch, _ in pairs(next_char) do
    local lower = vim.fn.tolower(ch)
    local upper = vim.fn.toupper(ch)
    if ch >= 'a' and ch <= 'z' and lower ~= upper and next_char[upper] then
      table.insert(lower_chars, ch)
    end
  end
  for _, lower in ipairs(lower_chars) do
    local upper = vim.fn.toupper(lower)
    local after = next_char[lower]
    next_char[lower] = upper
    next_char[upper] = after
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
  local rotations = M.defaults.rotations
  if opts.rotations then
    if opts.append_rotations ~= false then
      -- Append user rotations to defaults
      rotations = vim.list_extend(M.defaults.rotations, opts.rotations)
    else
      -- User rotations replace defaults entirely
      rotations = opts.rotations
    end
  end

  M.config = vim.tbl_deep_extend("force", M.defaults, opts)
  M.config.rotations = rotations
  M.config._next_char = next_char
  M.config._key = M.config.key

  build_lookup(M.config.rotations)

  vim.keymap.set("n", M.config.key, function() M.rotate() end, {
    desc = "Rotate character under cursor through configured variants",
  })
end

return M
