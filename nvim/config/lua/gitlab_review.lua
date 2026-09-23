-- gitlab.nvim: review GitLab merge requests inside nvim.  nvim only, being lua.
--
-- Auth comes from glab, at the moment the plugin asks for it, and from nowhere
-- else.  Not GITLAB_TOKEN in the environment, not a .gitlab.nvim file in the
-- project -- both put a live token somewhere it persists and gets copied.  glab
-- is already logged in to the instance this is for, so it is the one place the
-- token lives.
--
-- The host is read from glab as well rather than written down: this repository
-- is public, and the instance's name does not belong in it.
--
-- The provider FAILS CLOSED, and that is the part that matters.  gitlab.nvim's
-- state.lua does `gitlab_url = url or "https://gitlab.com"`, so a provider that
-- found a token but not a host would send an internal token to gitlab.com.  Any
-- missing piece therefore returns an error, which state.lua treats as "do not
-- set up" -- never a partial answer.
--
-- What actually carries the guarantee is that the token is looked up FOR the
-- host the url is built from, so the two cannot disagree.  The empty-host check
-- is belt and braces: measured with an empty GLAB_CONFIG_DIR, `glab config get
-- host` does not come back empty -- it answers gitlab.com -- and it is the token
-- lookup for that host that comes back empty and stops setup.
local ok, gitlab = pcall(require, 'gitlab')
if not ok then
  return
end

-- `glab config get` prints the value and nothing else; an unset key prints an
-- empty line and still exits 0, so emptiness is checked, not just the status.
local function glab_get(key, host)
  local cmd = { 'glab', 'config', 'get', key }
  if host then
    vim.list_extend(cmd, { '--host', host })
  end
  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  out = vim.trim(out)
  return out ~= '' and out or nil
end

local function auth_provider()
  if vim.fn.executable('glab') ~= 1 then
    return nil, nil, 'gitlab.nvim: glab is not on PATH'
  end
  local host = glab_get('host')
  if not host then
    return nil, nil, 'gitlab.nvim: glab has no default host'
  end
  local token = glab_get('token', host)
  if not token then
    return nil, nil, 'gitlab.nvim: glab has no token for its default host'
  end
  -- api_host is set when the API is served from a different name than the web
  -- UI; api_protocol defaults to https in glab itself.
  local api_host = glab_get('api_host', host) or host
  local protocol = glab_get('api_protocol', host) or 'https'
  return token, protocol .. '://' .. api_host, nil
end

gitlab.setup({
  auth_provider = auth_provider,
})

-- Replace the plugin's colour autocmd, which errors on every startup here.
--
-- lua/gitlab/colors.lua copies each discussion-tree colour with
-- synIDattr(id, "fg") and hands the result to nvim_set_hl as `fg`.  synIDattr
-- answers in the CURRENT colour mode, and the vimrc pins nvim to
-- notermguicolors, so it returns a cterm index such as '14' -- not a colour
-- name, so nvim_set_hl raises "Invalid highlight color: '14'" at VimEnter and
-- nvim stops on Press ENTER before the first screen.  Upstream assumes
-- termguicolors.
--
-- Copying the source group with nvim_get_hl carries fg/bg AND ctermfg/ctermbg,
-- which is right in either mode -- iblis.vim defines both palettes.  The group
-- names are derived from the plugin's own settings table (username ->
-- GitlabUsername, draft_mode -> GitlabDraftMode) so a new entry upstream is
-- picked up rather than silently missed.
--
-- The plugin's autocmd has no group or desc, so it is found by the file its
-- callback was defined in.  If upstream renames that file this finds nothing,
-- deletes nothing, and the startup error comes back -- loud, not silent.
local function gitlab_group(key)
  return 'Gitlab' .. key:gsub('^%l', string.upper):gsub('_(%l)', string.upper)
end

local function copy_discussion_colors()
  local source = require('gitlab.state').settings.colors.discussion_tree
  for key, from in pairs(source) do
    local h = vim.api.nvim_get_hl(0, { name = from, link = false })
    vim.api.nvim_set_hl(0, gitlab_group(key), {
      fg = h.fg, bg = h.bg, ctermfg = h.ctermfg, ctermbg = h.ctermbg,
    })
  end
end

for _, au in ipairs(vim.api.nvim_get_autocmds({ event = { 'VimEnter', 'ColorScheme' } })) do
  if type(au.callback) == 'function' then
    local src = debug.getinfo(au.callback, 'S').source
    if src:match('gitlab[/\\]colors%.lua$') then
      vim.api.nvim_del_autocmd(au.id)
    end
  end
end

vim.api.nvim_create_autocmd({ 'VimEnter', 'ColorScheme' }, {
  group = vim.api.nvim_create_augroup('GitlabReviewColors', { clear = true }),
  callback = copy_discussion_colors,
})
