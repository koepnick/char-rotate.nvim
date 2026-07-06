#!/usr/bin/env lua

-- Busted configuration for char-rotate.nvim

return {
  _all = {
    lpath = 'lua/?.lua;lua/?/init.lua',
    lua = 'nvim --cmd "set loadplugins" -l'
  },
  default = {
    verbose = true,
  },
  unit = {
    ROOT = {'./test/unit/'},
  }
}
