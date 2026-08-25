---
name: maintaining-vim-plugins
description: Use when updating vim or nvim plugins, when :PlugUpdate reports "Already up to date" on a plugin that is obviously years behind, when a plugin starts erroring after an editor upgrade, when :PlugClean deletes something it should not have, or when vim and nvim behave or render differently from the same config and the cause is not obvious.
---

# Maintaining vim/nvim plugins

## Overview

One `vimrc` shared by vim and nvim, `has('nvim')` branches, vim-plug. That
combination has four failure modes that are all **silent** — no error, just a
wrong result that looks right. The procedure below makes each one visible.

**Core principle: a plugin manager's "up to date" is a claim about a branch, not
about the plugin.** Verify against upstream, not against the tool's own report.

## When to use

- Before any bulk `:PlugUpdate` — the lock step is what makes it reversible
- A plugin throws deprecation warnings or errors after an editor upgrade
- `:PlugClean` removed a plugin you still use
- vim and nvim disagree about colours, highlighting or behaviour
- You have not updated in months and want to know how exposed you are

Not for: adding or removing a plugin, which is an ordinary `vimrc` edit.

## The update procedure

```sh
vim-plug-lock freeze            # 1. record the current good state

# 2. PlugClean is a PAIR of commands, never one.  Neither editor sees the whole
#    plugin set -- nvim-only Plug lines hide behind has('nvim') and vim-only
#    ones behind !has('nvim') -- so whichever editor cleans, the other must
#    immediately reinstall what it just orphaned.  Then assert the count.
vim  -c 'PlugClean!'         -c 'qa!'
nvim -c 'PlugInstall --sync' -c 'qa!'
vim-plug-lock status         # must name only what you meant to remove
vim-plug-lock restore        # the reinstall fetches HEAD; put the pins back
# 3. update in batches, verifying after each
vim  -c 'PlugUpdate --sync name1 name2' -c 'qa!'
vim  -c 'qa!'    # must be silent
nvim -c 'qa!'    # must be silent
vim-plug-lock status            # what actually moved
# 4. when everything passes
vim-plug-lock freeze            # record the new good state
```

`bin/vim-plug-lock` is in this repo and writes `vim/plug-lock.tsv`, which is
version-controlled — so the lock is both a rollback point and a way to reproduce
the same plugin set on another machine. `vim-plug-lock restore [name]` puts one
plugin or all of them back.

Batch rather than updating everything at once. Not for safety in the abstract:
when 20 plugins move at once and something breaks afterwards, nothing tells you
which one did it, and bisecting by hand across 20 repos is far more work than
running four batches.

## The four silent traps

| Symptom | Cause | Fix |
|---|---|---|
| `:PlugUpdate` says "Already up to date", plugin is years behind | Upstream renamed the default branch (`master` -> `main`, or `develop`). vim-plug **forces the branch recorded in the Plug spec on every update**, so fixing the checkout by hand is undone on the next run | Pin it: `Plug 'owner/repo', {'branch': 'main'}` |
| `:PlugClean` deletes a plugin you use | With a shared vimrc, `Plug` lines behind `has('nvim')` are invisible to vim and vice versa, so each editor considers the other's plugins orphaned. It is silent: the deletions scroll past in the same list as the intended one | Use the two-command pair in step 2 above, then `vim-plug-lock status`. Recovered twice by `nvim -c 'PlugInstall --sync'` followed by `vim-plug-lock restore` |
| An update fails for one plugin only | A tracked file was replaced locally by untracked ones — test fixtures with symlinks are the usual culprit — and git refuses to overwrite | `git -C <plugin> status --short --untracked-files=all`, clean the specific path, retry |
| A plugin errors only in nvim, only after some unrelated change | The plugin's nvim-specific code was dormant because the feature it hooks was never enabled. Enabling that feature wakes years-old code against a current API | Update the plugin; check whether upstream added a version guard |

## Verifying an update

After every batch, in this order:

1. **Both editors source the config silently** — `vim -c 'qa!'` and `nvim -c 'qa!'`
   with no output. Do this even when the batch touched nothing nvim-specific.
2. **The features you rely on still work**, asserted positively.

"No errors" is not evidence, and colour or rendering questions cannot be answered
from a headless run or from `:highlight` alone. See `measuring-vim-behaviour.md`.

## Common mistakes

- **Trusting `:PlugUpdate`'s own report.** It reports on the branch it pulled.
- **Running `:PlugClean` as a single command.** It is the clean-then-reinstall pair
  in step 2, always, and `vim-plug-lock status` is what proves it. Deciding which
  editor to clean in is not enough -- this was written as "decide first" and the
  trap was still walked into twice, because the deletion of the other editor's
  plugins is silent and reads as part of the intended cleanup.
- **Updating everything, then testing.** The lock makes it recoverable, not painless.
- **Treating a missing test fixture as a config failure.** Check the fixture exists
  before diagnosing; a probe against a file that was cleaned up reports the same
  emptiness as a broken feature.
