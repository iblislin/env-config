# Build and install the Rust hook binaries.
#
# WHY A STAMP, AND WHY IT IS CHECKED ONCE PER SESSION
# ---------------------------------------------------
# Until now every hook was a script: `git pull` and the new behaviour was live.
# A compiled hook breaks that, and it breaks it SILENTLY -- pull new sources,
# forget to rebuild, and the old binary keeps running with nobody able to tell.
# A hook that quietly enforces last month's rules is worse than one that is
# missing, because its absence is at least visible.
#
# So every binary answers `--stamp` with the source revision it was built from,
# and `make check-stamp` compares that against the working tree. The check runs
# from a SessionStart hook -- once per session, not once per tool call, because
# paying for staleness detection on every Bash call would spend exactly the
# milliseconds this migration exists to save.
#
# The stamp is the git HEAD plus a CONTENT HASH of this directory's sources.
#
# The obvious version -- HEAD plus a `git diff --quiet` dirty marker -- was
# tried and is broken here, for a reason worth recording: that check covers the
# WHOLE repository. This repo holds unrelated things (shell rc files, window
# manager config), so any edit anywhere pins the stamp at `-dirty` permanently,
# and once it is pinned, editing a `.rs` file no longer changes it. The marker
# that was supposed to catch a stale binary stops moving exactly when work is
# happening. A content hash of the sources that actually go into the binary
# moves when and only when they do.

PREFIX  ?= $(HOME)/bin
CARGO   ?= cargo
BINS     = src-write-diff-runner src-write-guard warn-sign-guard task-carry postcompact-hint
# DEFERRED (`=`, not `:=`) on purpose. With `:=` the hash is computed once when
# make PARSES this file -- before any recipe runs. `cargo build` then rewrites
# Cargo.lock whenever it is out of date (adding a workspace member does this),
# so the hash baked into the binary was computed from the OLD lockfile while the
# sub-make's `check-stamp` recomputed it from the NEW one. Result: every first
# build after a structural change reported STALE, and a second identical `make
# install` "fixed" it. A check whose answer depends on how many times you ran it
# is not a check. Deferred expansion evaluates each use at its own moment, and
# `build` settles the lockfile before the hash is ever read.
SRC_HASH = $(shell find $(CURDIR) -name target -prune -o -type f \
	    \( -name '*.rs' -o -name 'Cargo.toml' -o -name 'Cargo.lock' -o -name 'Makefile' \) \
	    -print 2>/dev/null | LC_ALL=C sort | xargs cat 2>/dev/null | sha256sum | cut -c1-10)
HEAD     = $(shell git -C $(CURDIR) rev-parse --short HEAD 2>/dev/null || echo nogit)
STAMP    = $(HEAD)-$(SRC_HASH)

.PHONY: all build install check check-stamp gate clean

all: build

build:
	@# Settle Cargo.lock BEFORE the stamp is read. `cargo metadata` resolves
	@# and writes the lockfile without compiling, so the hash computed on the
	@# next line is taken from the same lockfile the build will use.
	@$(CARGO) metadata --format-version 1 >/dev/null
	SRC_WRITE_STAMP=$(STAMP) $(CARGO) build --release

install: build
	@mkdir -p $(PREFIX)
	@for b in $(BINS); do \
	  install -m 0755 target/release/$$b $(PREFIX)/$$b && echo "installed $(PREFIX)/$$b"; \
	done
	@$(MAKE) --no-print-directory check-stamp

# The differential gate. This is what authorises a cutover -- not review.
# It fails loudly when either side is empty or never fires, because "0
# disagreements" and "the comparison never ran" are the same output otherwise.
gate: install
	$(HOME)/.claude/tools/src-write-diff verdicts --impl python
	$(HOME)/.claude/tools/src-write-diff verdicts --impl rust \
	    --binary $(PREFIX)/src-write-diff-runner
	$(HOME)/.claude/tools/src-write-diff compare \
	    $(HOME)/.claude/logs/src-write-diff/verdicts-python.jsonl \
	    $(HOME)/.claude/logs/src-write-diff/verdicts-rust.jsonl

check: gate
	$(HOME)/.claude/tools/src-write-diff selftest

# Exits non-zero, and names the fix, when an installed binary predates the
# working tree. Deliberately silent on success: it runs every session.
check-stamp:
	@fail=0; \
	for b in $(BINS); do \
	  if [ ! -x "$(PREFIX)/$$b" ]; then \
	    echo "STALE: $(PREFIX)/$$b is not installed -- run: make -C $(CURDIR) install" >&2; \
	    fail=1; continue; \
	  fi; \
	  got=$$($(PREFIX)/$$b --stamp 2>/dev/null); \
	  if [ "$$got" != "$(STAMP)" ]; then \
	    echo "STALE: $(PREFIX)/$$b built from '$$got', tree is '$(STAMP)' -- run: make -C $(CURDIR) install" >&2; \
	    fail=1; \
	  fi; \
	done; \
	exit $$fail

clean:
	$(CARGO) clean
