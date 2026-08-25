-- Python LSP for nvim, using the built-in client (nvim >= 0.11 for
-- vim.lsp.config/enable; no nvim-lspconfig needed).
--
-- The vim side runs the same two servers through yegappan/lsp, which is Vim9
-- script and cannot load here, so the knowledge is shared but the code is not.
-- Three things must stay in step with vim/vimrc, and each was a bug once:
--
--   * the server binaries live in ~/venv/py3. They are tools, not project
--     dependencies, and are absent from the per-project venvs.
--   * the interpreter is per-project. zshrc picks the venv from the tmux session
--     prefix, so $VIRTUAL_ENV is the authority; pinning one venv here would aim
--     the server at the wrong python for every project but one.
--   * root_markers must include pyproject.toml. The dispatcher cds to the repo
--     root rather than the package root, so without it every first-party import
--     in a repo whose package lives in a subdirectory reports as unresolved.

local tools = vim.fn.expand('~/venv/py3')
local venv = vim.env.VIRTUAL_ENV or tools

vim.lsp.config('basedpyright', {
  cmd = { tools .. '/bin/basedpyright-langserver', '--stdio' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'poetry.lock', 'setup.py', '.git' },
  settings = {
    python = { pythonPath = venv .. '/bin/python3' },
    basedpyright = {
      analysis = { diagnosticMode = 'openFilesOnly', typeCheckingMode = 'standard' },
    },
  },
})

-- Second on purpose: nvim merges diagnostics from every attached client, so ruff
-- adds lint on top while basedpyright keeps completion, hover and signature.
vim.lsp.config('ruff', {
  cmd = { tools .. '/bin/ruff', 'server' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'ruff.toml', '.git' },
})

vim.lsp.enable({ 'basedpyright', 'ruff' })
