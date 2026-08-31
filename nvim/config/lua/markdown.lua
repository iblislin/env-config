-- render-markdown.nvim: draw markdown in the buffer instead of showing its
-- syntax.  nvim only, being lua.
--
-- No setup() call: the plugin's own plugin/render-markdown.lua runs it from
-- vim.g.render_markdown_config, and vim-plug loads that before this file. So
-- everything below is a keymap, not configuration -- the defaults were measured
-- against a demo document and render correctly here, including under the
-- notermguicolors this config pins nvim to.  Every group resolves a cterm value
-- (RenderMarkdownCode ctermbg=4, H1Bg ctermbg=55, Quote ctermfg=224), which is
-- the thing that would otherwise have silently degraded.
--
-- Upstream lists nvim-treesitter as a dependency in every install recipe.  What
-- it needs is the markdown and markdown_inline PARSERS, which nvim 0.12 ships in
-- /usr/lib/nvim/parser; the plugin's lua contains no require('nvim-treesitter').
-- An icon provider (mini.icons, nvim-web-devicons) is also optional and not
-- installed: it only supplies the language icon above a code block, and the
-- checkbox, bullet, link and heading glyphs are literals in the plugin's own
-- config, so they render from the patched font already in use here.

-- The plugin has no default keymaps -- it renders on its own and needs no verb.
-- This one exists for the case it is built for: copying raw markdown out, where
-- the rendering is exactly what you do not want.  buf_toggle, not toggle, so it
-- affects the document in front of you and not every other markdown buffer.
vim.keymap.set('n', '<leader>m', '<cmd>RenderMarkdown buf_toggle<cr>',
  { silent = true, desc = 'toggle markdown rendering (this buffer)' })
