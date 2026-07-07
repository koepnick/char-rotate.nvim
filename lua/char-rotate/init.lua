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

-- Internal lookups: character -> next character in its rotation. A single
-- table can't represent both 'a' -> 'A' -> 'à' -> ... -> 'a' and
-- 'A' -> 'a' -> 'À' -> ... -> 'A' at once, since next('A') can't be both
-- 'à' and 'a'. So we keep two variants and pick between them per rotation
-- "session" (see `session` below): one rooted at the lowercase letter,
-- one rooted at the uppercase letter.
local next_char_by_root = { lower = {}, upper = {} }

-- Public: returns a lookup table (for testing). `root` is "lower" or
-- "upper"; defaults to "lower".
function M._get_next_char(root)
  return next_char_by_root[root or "lower"]
end

-- Build both lookup tables from a list of rotation strings.
-- We use vim.fn.split with empty separator + utf-8 awareness so that
-- multi-byte characters (é, ñ, etc.) are treated as single units.
--
-- For each ASCII letter pair (a/A, e/E, ...) found in the rotations, we
-- splice a case-toggle into each table:
--   lower-rooted: 'a' -> 'A' -> <A's own next in its group> -> ... -> 'a'
--   upper-rooted: 'A' -> 'a' -> <a's own next in its group> -> ... -> 'A'
-- so that starting a rotation from the lowercase letter cycles through
-- that letter's own diacritics after toggling case, and starting from the
-- uppercase letter cycles through its own diacritics symmetrically.
local function build_lookup(rotations)
  local base = {}
  for _, group in ipairs(rotations) do
    local chars = vim.fn.split(group, "\\zs")
    local n = #chars
    if n > 1 then
      for i, ch in ipairs(chars) do
        base[ch] = chars[(i % n) + 1]
      end
    end
  end

  local lower_root = vim.deepcopy(base)
  local upper_root = vim.deepcopy(base)

  local pairs_found = {}
  for ch, _ in pairs(base) do
    if ch >= 'a' and ch <= 'z' then
      local upper = vim.fn.toupper(ch)
      if upper ~= ch and base[upper] then
        table.insert(pairs_found, { lower = ch, upper = upper })
      end
    end
  end

  for _, p in ipairs(pairs_found) do
    lower_root[p.lower] = p.upper
    lower_root[p.upper] = base[p.lower]

    upper_root[p.upper] = p.lower
    upper_root[p.lower] = base[p.upper]
  end

  next_char_by_root.lower = lower_root
  next_char_by_root.upper = upper_root
end

-- Remembers which case a rotation "session" started from, keyed by buffer
-- and position, so repeated presses on the same spot stay within a single
-- case's ring. Reset (implicitly, via the position check) whenever the
-- cursor lands somewhere new.
local session = { bufnr = nil, row = nil, col = nil, root = nil }

-- Returns "lower" or "upper" for a cased character, or nil for a
-- caseless one (digits, symbols, etc.), where either table works the same.
local function root_for_char(char)
  local lower = vim.fn.tolower(char)
  local upper = vim.fn.toupper(char)
  if lower == upper then
    return nil
  end
  return char == lower and "lower" or "upper"
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
  local bufnr = vim.api.nvim_get_current_buf()

  do
    local char, row, c_start = char_under_cursor()
    if not char then return end
    if not (session.bufnr == bufnr and session.row == row and session.col == c_start) then
      session.bufnr = bufnr
      session.row = row
      session.col = c_start
      session.root = root_for_char(char) or "lower"
    end
  end

  local next_char = next_char_by_root[session.root]

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
  M.config._key = M.config.key

  build_lookup(M.config.rotations)
  session.bufnr = nil
  session.row = nil
  session.col = nil
  session.root = nil

  vim.keymap.set("n", M.config.key, function() M.rotate() end, {
    desc = "Rotate character under cursor through configured variants",
  })
end

return M
