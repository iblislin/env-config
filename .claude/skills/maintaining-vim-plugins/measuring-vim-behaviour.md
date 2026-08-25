# Measuring vim/nvim behaviour

Reference for the verification half of `maintaining-vim-plugins`. Every rule here
comes from a wrong conclusion that was reached first and had to be undone.

## The two rules everything else follows from

1. **Measure the rendered result, not the setting.** `:highlight` tells you the
   linkage; it does not tell you which of `ctermfg` and `guifg` the editor used.
2. **Measure late.** Anything negotiated with the terminal is not readable while
   the config is being sourced.

## Colours: capture the escape sequences

`tmux capture-pane -p` strips attributes. `-e` keeps them:

```sh
tmux -L probe new-session -d -s t -x 160 -y 20
tmux -L probe send-keys -t t 'vim file.py' Enter; sleep 7
tmux -L probe capture-pane -e -p -t t \
  | grep -a 'the line you care about' | cat -v \
  | sed 's/\^\[\[/\n  ESC[/g'
tmux -L probe kill-server
```

Read the result by prefix:

| Escape | Meaning |
|---|---|
| `ESC[33m` | 16-colour foreground — the editor used `ctermfg` |
| `ESC[38;5;N m` | 256-colour foreground — still `ctermfg` |
| `ESC[38;2;R;G;B m` | 24-bit — the editor used **`guifg`** |
| one long run over a whole line | nothing is being highlighted |

`-L <name>` runs a separate tmux server, so probing never disturbs a real session.

## Options negotiated with the terminal

`termguicolors` in nvim is **0 while the vimrc is sourced** and flips to 1 once the
terminal answers a capability query. Reading it at source time gives the
pre-flip value, which is a correct-looking wrong answer.

```vim
autocmd VimEnter * call timer_start(3000, {-> execute('echo &termguicolors')})
```

The same applies to anything else the TUI negotiates. If a value seems to
contradict what you can see on screen, read it later before disbelieving the screen.

## Headless runs lie about colours

`vim --not-a-term` and `nvim --headless` report different default highlight
attributes than the same editors in a terminal — the same colorscheme yielded
`ctermfg=11` headless and `ctermfg=14` in a tmux pane. Headless is fine for
diagnostics, buffer contents and option values; anything about colour or drawing
needs a real pty.

## Launch each editor the way it really launches

nvim reaches a shared vimrc through its own `init` file, which sets
`runtimepath`. Running `nvim -u path/to/vimrc` **skips that**, so `~/.vim` is not
on the runtimepath and you get fabricated errors — missing colorscheme, unknown
`plug#begin`, then an `E492` per `Plug` line. None of them are real. Run plain
`nvim` and let it find its own init.

## "No errors" is not evidence

A file-tree drawer silently stopped rendering and survived a whole change,
because the check was "`:messages` is clean" — and it was. Assert positively
instead: the buffer has N lines, `filetype` is what it should be, `buftype` is
set, the syntax group under the cursor is the expected one.

```vim
" the shape of a useful assertion
echo printf('lines=%d filetype=%s buftype=%s', line('$'), &filetype, &buftype)
```

## Verify the fixture before believing the result

A probe against a file that no longer exists reports exactly what a broken
feature reports: nothing. Twice in one session an "LSP returns no completions"
finding turned out to be a scratch file that had been cleaned up. Check the
fixture exists and has the content you think it has, in the same command that
measures.

## Measuring staleness honestly (plugin freshness)

```sh
gh api repos/<owner>/<repo> --jq '.pushed_at, .archived, .default_branch'
```

⚠️ **`pushed_at` is repo-wide, not per-branch.** A plugin whose default branch has
not moved in three years still reports a recent `pushed_at` if anyone pushed to
any branch. It overstates freshness and it overstates staleness in the other
direction too — compare `default_branch` against the branch actually checked out
before concluding anything.

`archived: true` does not mean broken. It means nobody will fix it the next time
an editor removes an API, which makes it a candidate for the fourth trap above.

## expect versus tmux

Both are useful; they answer different questions.

| Question | Tool | Why |
|---|---|---|
| What colour/attribute was drawn? | **tmux `capture-pane -e`** | tmux emulates a terminal and keeps a screen model; expect only sees a byte stream |
| Did it happen, and how long did it take? | **expect** | `expect "pattern"` waits for a specific output instead of guessing with `sleep`, and reports elapsed time |
| Would my real terminal enable this feature? | **neither** | both answer the capability query differently from your terminal. Measure in the real session |

Most probes in this repo use tmux with fixed `sleep`s. That is adequate for
"is it there after N seconds" and inadequate for "how long did it take" — reach
for expect when the timing itself is the question.

## Interrogating a running editor

Faster than reconstructing a scenario:

```vim
:echo exists('#SafeState')        " a ++once autocmd is removed after it fires,
                                  " so a surviving entry proves it never fired
:echo timer_info()                " what is still pending
:echo prop_list(line('.'))        " vim: which text properties cover this line
:lua =vim.lsp.get_clients()       " nvim: which LSP clients attached
```
