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
# The stamp is the git HEAD plus a dirty marker. A dirty tree always reports
# stale, which is the correct answer while iterating: the binary genuinely does
# not correspond to anything committed.

PREFIX  ?= $(HOME)/bin
CARGO   ?= cargo
BINS     = src-write-diff-runner src-write-guard
STAMP   := $(shell git -C $(CURDIR) rev-parse --short HEAD 2>/dev/null || echo unknown)$(shell git -C $(CURDIR) diff --quiet 2>/dev/null || echo -dirty)

.PHONY: all build install check check-stamp gate clean

all: build

build:
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
