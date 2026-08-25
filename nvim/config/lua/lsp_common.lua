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

-- nvim 0.11 claimed the whole `gr` prefix for its LSP defaults, which collides
-- with the vimrc's `gr` -> :tabp: pressing it stalls for 'timeoutlen' while nvim
-- waits to see whether an n/r/a/i/t/x follows.  Measured at 1123 ms against
-- 20 ms for gt, so the tab key is the one that has to win -- it is pressed
-- constantly, the LSP verbs are not.
--
-- The six defaults move to a <leader>l prefix rather than being dropped, and the
-- vimrc gives yegappan/lsp the same keys, so the two editors agree.
for _, lhs in ipairs({ 'grn', 'grr', 'gri', 'grt', 'grx' }) do
  pcall(vim.keymap.del, 'n', lhs)
end
-- gra is Normal *and* Visual mode, unlike the rest.
pcall(vim.keymap.del, { 'n', 'x' }, 'gra')

-- Buffer-local, so these exist only where a server actually attached.
local verbs = {
  { 'lr', vim.lsp.buf.rename,          'LSP rename' },
  { 'lR', vim.lsp.buf.references,      'LSP references' },
  { 'la', vim.lsp.buf.code_action,     'LSP code action' },
  { 'li', vim.lsp.buf.implementation,  'LSP implementation' },
  { 'lt', vim.lsp.buf.type_definition, 'LSP type definition' },
  { 'lx', vim.lsp.codelens.run,        'LSP run codelens' },
}
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    for _, v in ipairs(verbs) do
      vim.keymap.set('n', '<leader>' .. v[1], v[2],
        { buffer = ev.buf, silent = true, desc = v[3] })
    end
  end,
})

-- gd is deliberately the only other keymap set here.  nvim already provides grn, grr,
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
