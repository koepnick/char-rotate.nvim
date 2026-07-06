-- char-rotate.nvim
-- Auto-load the module with defaults. Users call setup() via their own
-- config or through lazy.nvim opts to override behavior.

local M = {}

function M.setup(opts)
  require("char-rotate").setup(opts or {})
end

return M
