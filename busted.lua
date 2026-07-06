-- Busted configuration for char-rotate.nvim
-- Uses Neovim as the Lua interpreter so that `require("char-rotate")` works.

return {
  _all = {
    lpath = 'lua/?.lua;lua/?/init.lua',
    lua = './test/nvim-shim'
  },
  default = {
    verbose = true,
  },
  unit = {
    ROOT = './test/unit',
  }
}
