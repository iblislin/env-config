-- Behaviour shared by every LSP server nvim starts.  It lives on its own because
-- it used to live in python_lsp.lua, where it silently governed the TypeScript
-- servers too -- the autocmd matches any client, so the filename lied about its
-- reach.  Load this before any per-language module.

-- Auto-completion fires on each server's own triggerCharacters ('.' among them).
-- The Tab cycling and 'completeopt' live in the shared vimrc's has('nvim') branch.
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end
  end,
})

-- gd is deliberately the only keymap set here.  nvim already provides grn, grr,
-- gra, gri and gO globally, and maps K to hover on attach -- but only when no
-- custom K mapping exists, which the vimrc's dead LanguageClient-neovim block
-- used to defeat.  gd has no LSP default: 'tagfunc' makes <C-]> work instead,
-- and plain gd stays vim's local-declaration search wherever no server attached.
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method('textDocument/definition') then
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition,
        { buffer = ev.buf, silent = true, desc = 'LSP go to definition' })
    end
  end,
})

vim.diagnostic.config({ virtual_text = true, severity_sort = true })
