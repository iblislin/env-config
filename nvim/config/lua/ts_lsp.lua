-- TypeScript/JavaScript LSP for nvim, using the built-in client.  vtsls wraps
-- the same tsserver extension VS Code ships, so it is the closest match to what
-- the rest of the team sees.
--
-- vim has no counterpart: yegappan/lsp could drive vtsls too, but the vim side
-- is deliberately kept to the non-LSP half of the workflow.
--
-- Two project-shaped traps, both measured rather than assumed:
--
--   * `vtsls.autoUseWorkspaceTsdk` is not a nicety.  The server bundles its own
--     TypeScript (5.9.3 as of vtsls 0.3.0) while a project pins its own, so
--     without this the editor reports diagnostics the build never produces.
--     This is the tsdk analogue of python's per-project $VIRTUAL_ENV.
--   * root_markers is ordered, and `angular.json` must outrank `package.json`.
--     An Angular workspace has a package.json per library under projects/, none
--     of which has a node_modules; rooting there makes every dependency
--     unresolved.  vim.fs.root evaluates each entry against ALL ancestors before
--     moving to the next, so this ordering picks the workspace, not the library.

local tsdk = { autoUseWorkspaceTsdk = true }

vim.lsp.config('vtsls', {
  cmd = { 'vtsls', '--stdio' },
  filetypes = {
    'typescript', 'typescriptreact', 'typescript.tsx',
    'javascript', 'javascriptreact', 'javascript.jsx',
  },
  root_markers = { 'angular.json', 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
  -- Sent at initialize and again on didChangeConfiguration: the server reads the
  -- tsdk choice from the former, the rest from the latter.
  init_options = { vtsls = tsdk },
  settings = {
    vtsls = tsdk,
    typescript = {
      updateImportsOnFileMove = { enabled = 'always' },
      inlayHints = {
        parameterNames = { enabled = 'literals' },
        functionLikeReturnTypes = { enabled = false },
      },
    },
  },
})

vim.lsp.enable('vtsls')
