-- Tab-oriented navigation.  `vi` is `nvim -p` and the fern drawer is per-tab, so
-- a file is a tab; these make gf and gd agree with that, and with telescope's
-- select_tab_drop in finder.lua.
--
-- Deliberately not built on `:tab drop`, which looks like exactly this and
-- carries a clause that makes it unusable here: ":drop ... Windows that are not
-- in the argument list or are not full width will be closed if possible" -- the
-- fern drawer is neither.
local M = {}

-- Jump to the window already showing `file` in any tab, else open a new tab.
function M.tab_drop(file, lnum, col)
  local target = vim.fn.fnamemodify(file, ':p')
  local found
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
      if name ~= '' and vim.fn.fnamemodify(name, ':p') == target then
        found = win
        break
      end
    end
    if found then break end
  end
  if found then
    vim.api.nvim_set_current_win(found)
  else
    vim.cmd('tabnew ' .. vim.fn.fnameescape(target))
  end
  if lnum then
    vim.api.nvim_win_set_cursor(0, { lnum, (col or 1) - 1 })
  end
end

-- What `gf` would open, or nil.  Mirrors 'path' as it is set here (`.,,` -- the
-- buffer's directory, then the cwd) and honours 'suffixesadd', which is what
-- lets `from './foo'` find foo.ts.  Resolved rather than handed to gf so the
-- caller can decide between a file jump and an LSP request BEFORE moving.
function M.file_under_cursor()
  local cfile = vim.fn.expand('<cfile>')
  if cfile == '' then
    return nil
  end
  local suffixes = { '' }
  for _, s in ipairs(vim.split(vim.bo.suffixesadd or '', ',', { trimempty = true })) do
    suffixes[#suffixes + 1] = s
  end
  for _, dir in ipairs({ vim.fn.expand('%:h'), vim.fn.getcwd() }) do
    for _, suffix in ipairs(suffixes) do
      local p = vim.fs.normalize(dir .. '/' .. cfile .. suffix)
      if vim.fn.filereadable(p) == 1 then
        return p
      end
    end
  end
  local p = vim.fn.expand(cfile)
  if p ~= '' and vim.fn.filereadable(p) == 1 then
    return p
  end
  return nil
end

-- gd, VS Code style: one key for "take me to whatever this is".  A path goes to
-- the file, anything else to the language server.  The path check runs first and
-- synchronously, because vim.lsp.buf.definition's on_list fires only for a
-- NON-empty result -- so an LSP miss cannot be caught and turned into a fallback,
-- it just prints "No locations found".  That is the bug this replaces: gd on
-- `templateUrl: './x.pug'` asked tsserver for the definition of a string.
function M.goto_definition()
  local file = M.file_under_cursor()
  if file then
    M.tab_drop(file)
    return
  end
  vim.lsp.buf.definition({
    on_list = function(opts)
      local item = opts.items[1]
      if not item then
        return
      end
      M.tab_drop(item.filename, item.lnum, item.col)
      if #opts.items > 1 then
        vim.fn.setqflist({}, ' ', opts)
        vim.notify(('%d definitions; the rest are in the quickfix list'):format(#opts.items))
      end
    end,
  })
end

return M
