# Working on this vim/nvim config

One `vimrc` serves both editors. Vim 9.2 reads it directly; nvim reaches it via
`~/.config/nvim/init.vim`, which is NOT in this repo and does:

```vim
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vim/vimrc
```

As of 2026-08-24 nvim 0.12.4 sources the whole file with **zero errors**. Keep it
that way: put anything vim-only behind `if !has('nvim')`.

## Measuring, before changing anything

Every wrong conclusion recorded below came from measuring at the wrong moment or
measuring the wrong layer, not from a wrong hypothesis.

### Options negotiated with the terminal are not readable at source time

`&termguicolors` in nvim is **0 while the vimrc is being sourced** and flips to 1
once the terminal answers nvim's capability query. Read it from a timer instead:

```vim
autocmd VimEnter * call timer_start(3000, {-> execute('echo &termguicolors')})
```

Measured: `tgc_at_3s=1` for nvim, `0` for vim. Four probes in a row read 0 for
nvim because they read during sourcing, which refuted a hypothesis that was
correct.

### Colours: measure what was rendered, not what the highlight table says

`:highlight Foo` tells you the linkage. It does not tell you which of `ctermfg`
and `guifg` the editor actually used. `tmux capture-pane -p` strips that too --
**`-e` keeps the SGR escapes**:

```sh
tmux -L probe new-session -d -s t -x 110 -y 12
tmux -L probe send-keys -t t 'vim file.py' Enter; sleep 7
tmux -L probe capture-pane -e -p -t t | grep -a import | cat -v | sed 's/\^\[\[/\n  ESC[/g'
```

The finding that settled a whole investigation:

| editor | rendered | meaning |
|---|---|---|
| vim | `ESC[33m from` `ESC[97m os` `ESC[33m import` | 16-colour, per-token: highlighted |
| nvim | `ESC[38;2;224;226;234m from os import path` | one 24-bit grey run: not highlighted |

### Headless runs lie about colours; use a real pty

`vim --not-a-term` / `nvim --headless` reported `Statement ctermfg=11` vs `14`
for the same colorscheme. In a tmux pane both report `14`. Anything about
colours, `termguicolors`, or drawing must run in tmux.

### nvim must be launched the way it really launches

`nvim -u vim/vimrc` skips `~/.config/nvim/init.vim`, so `~/.vim` is not on
`runtimepath` and you get fabricated errors -- `E185: Cannot find color scheme
'iblis'`, `E117: Unknown function: plug#begin`, then a cascade of `E492` on every
`Plug` line. Run plain `nvim` and let it find its own init.

### "No errors" is not evidence

A fern regression survived a completion-stack rewrite because the check was
`:messages` is clean -- and it was. Assert positively instead: the drawer has N
lines, `filetype=fern`, `buftype=nofile`.

## colors/iblis.vim carries two palettes, and both are applied

It used to gate them:

```
line  14: if has("gui_running")     <- every gui= / guifg= lived here
line 103: else                      <- every cterm= / ctermfg= lived here
line 185: endif
```

A terminal always takes the `else` branch, so in a terminal the scheme defined
**no gui attributes at all**, and any editor with `termguicolors` on fell back to
its own defaults. That is why `from ... import ...` rendered grey in nvim.

Fixed 2026-08-24 by running both halves unconditionally. Two things to preserve:

- **cterm comes first.** The cterm half does `hi clear` on the `Spell*` groups,
  which would wipe the gui undercurl if it ran second. A `:highlight` command
  only touches the colour space it names, so otherwise the halves compose.
- `Function`, `Keyword`, `Structure` and `ColorColumn` were cterm-only. Their gui
  values are the xterm palette entries for those exact indices, measured at
  `t_Co=256` (81 -> #5fd7ff, cyan=14 -> #00ffff, red=9 -> #ff0000, 4 -> #0000ee),
  so nothing new was invented.

**The two palettes are different by design** -- PreProc is cterm 3 (dark yellow)
but gui #409090 (teal) -- so running nvim on truecolor makes the two editors look
unlike each other. That is not wanted here, so the vimrc pins nvim to the cterm
half:

```vim
if has('nvim')
    set notermguicolors
endif
```

This has to be an explicit `set`, not a hope: nvim negotiates truecolor
asynchronously *after* the vimrc is sourced, which is why `&termguicolors` reads 0
during sourcing and 1 a moment later. The option's docs promise auto-detection
happens "unless explicitly disabled by the user", and measurement agrees --
`tgc` is still 0 three seconds in.

Keep the two-palette restructure anyway. It costs nothing and it is what stops
the colours collapsing to grey if truecolor is ever switched on, by hand or by a
GUI client.

Verified: vim's rendered escapes are byte-identical before and after
(`ESC[33mfrom`, `ESC[97m os`, `ESC[33mimport`), and nvim went from one grey run
to `ESC[38;2;64;144;144mimport`, which is #409090.

## LSP (`yegappan/lsp`, vim only -- it is Vim9 script, nvim cannot load it)

- The plugin declares `def g:LspAddServer()`. The name needs the **`g:` prefix**.
- `plugin/lsp.vim` is sourced by vim **after** this vimrc finishes, so
  `exists('*LspAddServer')` here is *always* false. Guarding on it registers
  nothing, silently -- that is why the java entry was dead for years. Register
  from `VimEnter`.
- Do **not** set `syncInit`. It blocks vim while waiting for `initialize`, timers
  keep firing during the block, and a fern drawer opened from such a timer never
  runs its `BufReadCmd`.
- The interpreter is per-project: zshrc picks the venv from the tmux session
  prefix, so read `$VIRTUAL_ENV` and fall back to `~/venv/py3`. The server
  binaries stay in `~/venv/py3` -- they are tools, absent from project venvs.
- `rootSearch` is required. The dispatcher cds to the repo root, not the package
  root, so without it every first-party import reports unresolved.

## fern

- Startup opening runs on `SafeState ++once`, not `VimEnter`. Opening the drawer
  while LSP registration is still in flight leaves the `fern://` buffer
  uninitialised: empty, `buftype` unset, `[New DIRECTORY]` on the message line.
- `fern#hook#emit` wraps callbacks in `try/catch` and sends exceptions to
  `fern#logger#error`, which is **silent** unless `g:fern#logfile` is set. Set it
  before concluding a hook is not firing.
- Hook callbacks run with the **file** window current, not the fern buffer. Use
  the `helper` argument: `helper.bufnr`, and `win_execute(helper.winid, ...)`.
  `win_execute` does not trigger autocommands, which also keeps a measurement
  from causing the refresh it is trying to observe.
- fern is plain vimscript and works in nvim unchanged.

## Completion has exactly one owner

`yegappan/lsp` in vim; nvim's built-in `vim.lsp` when that is set up. supertab,
AutoComplPop, ncm2, LanguageClient-neovim, vim-nodejs-complete and
clang-complete were all removed for this reason -- do not reintroduce them. The
Tab-cycling behaviour people miss from supertab is the `pumvisible()` mappings in
the nvim branch, which depend on no plugin. `jedi-vim` stays, with
`completions_enabled = 0`.

Two ftplugins used to set `g:SuperTabDefaultCompletionType` **globally**, from
python and erlang; both are gone.
