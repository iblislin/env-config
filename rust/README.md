# Hook binaries

Claude Code hooks, compiled. They run once per tool call, do a few hundred
microseconds of real work, and used to spend 20–60 ms each starting a Python
interpreter to do it.

## The numbers this is based on

Measured on this machine, medians over 15–30 runs, with a realistic payload on
stdin:

| hook | language | median |
|---|---|---|
| `claude-src-write-guard` | python | 61.1 ms |
| `claude-src-write-hint` | python | 52.5 ms |
| `claude-warning-sign-guard` | python | 36.7 ms |
| `claude-mr-watch-hint` | python | 32.5 ms |
| `claude-glab-guard` | bash + jq | 22.7 ms |
| `claude-paru-guard` | bash | 10.7 ms |

Interpreter floors, same conditions:

```
python3 -c pass                          19.2 ms
python3 -S -c pass                       11.6 ms
python3 -c 'import json,os,re,subprocess,sys'  39.8 ms
bash -c true                              1.3 ms
jq -n 1                                   2.0 ms
rust binary reading stdin                 0.65 ms
```

**Almost none of the cost is the logic.** Loading the 20 KB guard as a module
(36.5 ms) is the same as just doing its five stdlib imports (39.8 ms) — the
twenty-odd `re.compile` calls and the whole body are lost in the noise. What
costs is starting the interpreter and importing `json`, `re` and `subprocess`.

## Hooks for one event run in PARALLEL

Measured with three 0.4 s hooks armed on one event: all three started within
1.6 ms of each other and finished together. So the cost of an event is `max()`
of its hooks, not `sum()` — which is the single most important fact for
deciding what to port.

| event | today | after everything |
|---|---|---|
| PreToolUse on Bash | 61 ms | ~1 ms |
| PostToolUse on Bash | 52.5 ms | ~1 ms |

For scale: the Bash tool itself takes ~1.7 s for a bare `echo`, because it
starts a shell from the user's profile. The hooks are a few percent of that.
This work is worth doing because it is cheap and permanent, not because hooks
were ever the bottleneck.

## Porting order is forced by the parallelism

Only the slowest hook on an event matters, so each port promotes a new one into
the critical path. Porting out of order buys nothing:

| step | port | PreToolUse after | PostToolUse after |
|---|---|---|---|
| 1 | `src-write-guard` | 36.7 ms (`warning-sign-guard`) | — |
| 2 | `warning-sign-guard` | 22.7 ms (`glab-guard`) | — |
| 3 | `src-write-hint` | — | 32.5 ms (`mr-watch-hint`) |
| 4 | `mr-watch-hint` | — | ~1 ms |
| 5 | `glab-guard` | 10.7 ms (`paru-guard`) | — |
| 6 | `paru-guard` | ~1 ms | — |

Note steps 3 and 4: PostToolUse has only two hooks, so porting one of them
leaves the other as the ceiling. Half the work buys 20 ms; all of it buys 51 ms.

## The gate — what authorises a cutover

Not review. `claude-src-write-guard` carries a documented false-positive history
(roughly 39% down to near zero) that exists nowhere except in the shape of its
regexes and the order they are applied in. A reimplementation that merely looks
equivalent silently re-opens all of it, and the failure is invisible: a guard
that stops denying looks exactly like a guard with nothing to deny.

So a port ships only when it agrees with the original on every row of a corpus
of real commands:

```
make gate
```

That builds, installs, runs the Python baseline and the Rust port over the same
corpus, and compares positionally. The bar is `# DISAGREEMENTS : 0`.

The corpus is built by `~/.claude/tools/src-write-diff` from real session
transcripts — currently 75,991 unique `(cwd, command)` pairs — plus a
hand-written tail. **The tail is not optional:** the real corpus exercised six
of the guard's seven rule families and fired `tee` exactly zero times, so a port
that dropped `tee` entirely would have passed a 76,000-row gate. A corpus is a
sample of what happened, never of what the guard must handle.

Three controls make a clean result mean something, because "0 disagreements" and
"the comparison never ran" are otherwise the same output:

- `extract` refuses to emit an empty corpus and prints what it drew from;
- `verdicts` fails if nothing fires, on either side;
- `selftest` mutates a known verdict and asserts the comparator reports it.

**The corpus holds real commands and is never committed.** It is written 0600
under `~/.claude/logs/`, which that repo's allowlist `.gitignore` excludes.

## Staleness — the thing compiling breaks

A script hook goes live on `git pull`. A compiled one does not, and the failure
is silent: last month's rules keep being enforced with nothing to show it.

Every binary answers `--stamp` with the revision it was built from.
`make check-stamp` compares that against the working tree and names the fix.
`bin/claude-hook-stamp-check` runs it from `SessionStart` — once per session,
never per tool call, since spawning `make` costs more than the hooks it checks.
It always exits 0: a hygiene notice must not be able to fail a session start.

## This repository is PUBLIC

No internal hostnames, addresses, project or group names, or credentials in any
file here — comments, tests and `Cargo.lock` included. Hooks whose text names
internal systems live in the private config repo instead, not here.
