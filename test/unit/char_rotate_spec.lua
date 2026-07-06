-- Tests for char-rotate.nvim rotation lookup and configuration

local char_rotate = require('char-rotate')

describe('Rotation lookup', function()
  it('builds lookup from simple rotation groups', function()
    char_rotate.setup({ rotations = { 'abc' }, append_rotations = false })
    local next_char = char_rotate._get_next_char()
    assert.are.equal('b', next_char['a'])
    assert.are.equal('c', next_char['b'])
    assert.are.equal('a', next_char['c'])
  end)

  it('handles multi-byte characters', function()
    char_rotate.setup({ rotations = { 'aàá' }, append_rotations = false })
    local next_char = char_rotate._get_next_char()
    assert.are.equal('à', next_char['a'])
    assert.are.equal('á', next_char['à'])
    assert.are.equal('a', next_char['á'])
  end)

  it('inserts case-toggle for ASCII letters', function()
    char_rotate.setup({ rotations = { 'aàá', 'AÀÁ' }, append_rotations = false })
    local next_char = char_rotate._get_next_char()
    assert.are.equal('A', next_char['a'])
    assert.are.equal('à', next_char['A'])
    assert.are.equal('à', next_char['à'])
    assert.are.equal('á', next_char['à'])
  end)

  it('handles special characters without case-toggle', function()
    char_rotate.setup({ rotations = { '-_' }, append_rotations = false })
    local next_char = char_rotate._get_next_char()
    assert.are.equal('_', next_char['-'])
    assert.are.equal('-', next_char['_'])
  end)

  it('handles single character groups gracefully', function()
    char_rotate.setup({ rotations = { 'a' }, append_rotations = false })
    local next_char = char_rotate._get_next_char()
    assert.is_nil(next_char['a'])
  end)

  it('handles empty rotation groups', function()
    char_rotate.setup({ rotations = { '' }, append_rotations = false })
    local next_char = char_rotate._get_next_char()
    assert.is_nil(next_char['a'])
  end)
end)

describe('Configuration', function()
  it('appends rotations by default', function()
    char_rotate.setup({ rotations = { 'xy' } })
    local next_char = char_rotate._get_next_char()
    -- Should have both default rotations (e.g., 'a' from "aàáâãäåā") and user rotations
    assert.truthy(next_char['a'])
    assert.are.equal('y', next_char['x'])
  end)

  it('replaces rotations when append_rotations is false', function()
    char_rotate.setup({
      rotations = { 'xy' },
      append_rotations = false,
    })
    local next_char = char_rotate._get_next_char()
    assert.is_nil(next_char['a'])
    assert.are.equal('y', next_char['x'])
  end)

  it('uses configured key', function()
    char_rotate.setup({
      key = '<leader>r',
      append_rotations = false,
      rotations = { 'ab' },
    })
    -- Verify the keymap is set
    local map = vim.api.nvim_buf_get_keymap(0, 'n')
    local found = false
    for _, m in ipairs(map) do
      if m.lhs == '<leader>r' then
        found = true
        break
      end
    end
    assert.is_true(found)
  end)

  it('uses default key "~" when not configured', function()
    char_rotate.setup({
      append_rotations = false,
      rotations = { 'ab' },
    })
    local map = vim.api.nvim_buf_get_keymap(0, 'n')
    local found = false
    for _, m in ipairs(map) do
      if m.lhs == '~' then
        found = true
        break
      end
    end
    assert.is_true(found)
  end)

  it('preserves other configuration options', function()
    char_rotate.setup({
      append_rotations = false,
      rotations = { 'ab' },
      fallback_to_case_toggle = false,
    })
    assert.is_false(char_rotate._config.fallback_to_case_toggle)
  end)
end)

describe('Edge cases', function()
  it('handles duplicate characters in rotation', function()
    char_rotate.setup({ rotations = { 'aa' }, append_rotations = false })
    local next_char = char_rotate._get_next_char()
    assert.are.equal('a', next_char['a'])
  end)

  it('handles multiple rotation groups with overlapping characters', function()
    -- This is an edge case - overlapping characters would cause undefined behavior
    -- The current implementation will use the last definition
    char_rotate.setup({ rotations = { 'ab', 'ac' }, append_rotations = false })
    local next_char = char_rotate._get_next_char()
    -- 'a' should map to 'b' (first group) then 'c' (second group overrides)
    assert.are.equal('c', next_char['a'])
  end)

  it('handles very long rotation strings', function()
    local long_rotation = ''
    for i = 1, 100 do
      long_rotation = long_rotation .. string.char(0x41 + (i % 26))
    end
    char_rotate.setup({ rotations = { long_rotation }, append_rotations = false })
    local next_char = char_rotate._get_next_char()
    -- Check that rotation works for all characters
    for i = 1, #long_rotation do
      local ch = long_rotation:sub(i, i)
      assert.truthy(next_char[ch])
    end
  end)
end)
