#!/usr/bin/env python3
"""Regression matrix for `claude-src-write-guard`.

Run: python3 tests/test-claude-src-write-guard.py

Every case is a (command -> DENY|allow) assertion fed through the hook's real
stdin/stdout contract, so this exercises the shipped code path rather than an
imported copy of the regexes.

Two properties this file exists to protect, both of which a plain "does it
block a sed -i" smoke test would miss:

1. **A control that must DENY, in the same run as the negatives.** A guard that
   crashes fails open, and every negative case then passes for the wrong
   reason. The pass/fail line below is void unless the DENY cases fire.
2. **Read-only commands must survive.** The guard's history is a 39% false
   positive rate over 56,513 real commands, so the negatives are the point.
"""
import json
import os
import subprocess
import sys

GUARD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bin",
                     "claude-src-write-guard")
# A directory that really is inside a git work tree, since the guard checks.
REPO = os.path.expanduser("~/env-config")

CASES = [
    # --- must DENY: these are the guard's job ------------------------------
    ("sed -i on a .py in a git tree",
     "sed -i 's/a/b/' %s/bin/x.py" % REPO, "DENY"),
    ("sed -i on a .md in a git tree",
     "sed -i 's/a/b/' %s/README.md" % REPO, "DENY"),
    ("sed -i on a .tex in a git tree (added 2026-09-07)",
     "sed -i 's/a/b/' %s/doc/a.tex" % REPO, "DENY"),
    ("heredoc into a .py",
     "cat > %s/bin/x.py <<'EOF'\nprint(1)\nEOF" % REPO, "DENY"),
    ("perl -i on a .py",
     "perl -i -pe 's/a/b/' %s/bin/x.py" % REPO, "DENY"),

    # --- extensionless scripts, covered from 2026-09-10 --------------------
    # `bin/` has no extensions at all, so the extension list could never
    # protect the directory these hooks live in. `is_script` narrows the broad
    # patterns by shebang instead.
    ("sed -i on an extensionless script (shebang)",
     "sed -i 's/a/b/' %s/bin/claude-src-write-hint" % REPO, "DENY"),
    ("redirect into an extensionless script",
     "echo x > %s/bin/claude-src-write-hint" % REPO, "DENY"),
    ("literal open(...,'w') on an extensionless script",
     "python3 -c \"open('%s/bin/claude-src-write-hint','w').write('x')\"" % REPO,
     "DENY"),

    # --- must ALLOW: the false positives that actually happened -----------
    ("2026-09-10: `sed` one line, an unrelated `-i` the next",
     "rg -c 'x' f | sed 's/^/h: /'\nrg -n -i 'pat' %s/README.md" % REPO,
     "allow"),
    ("same two statements joined with `;` (was already allowed)",
     "rg -c 'x' f | sed 's/^/h: /' ; rg -n -i 'pat' %s/README.md" % REPO,
     "allow"),
    ("reading a source file",
     "cat %s/bin/claude-src-write-guard" % REPO, "allow"),
    # The broad extensionless patterns hand `is_script` every bare redirect
    # target in the command, so these negatives are what keep the second pass
    # from becoming a flood. Each fails a different one of its three checks.
    ("/dev/null is not a regular file",
     "echo x > /dev/null", "allow"),
    ("an extensionless file with NO shebang is data, not source",
     "echo x > %s/README" % REPO, "allow"),
    ("a target that does not exist yet has no shebang to read",
     "echo x > %s/bin/brand-new-thing" % REPO, "allow"),
    ("an extensionless script under a scratch path stays exempt",
     "sed -i 's/a/b/' /tmp/some-script", "allow"),
    ("the command that motivated the fix is STILL allowed -- gap 1, the "
     "variable-held path, is a separate hole and remains open",
     "python3 -c \"p='%s/bin/claude-src-write-hint'\nopen(p,'w').write('x')\"" % REPO,
     "allow"),
    ("sed -n is a read, not a write",
     "sed -n '1,10p' %s/README.md" % REPO, "allow"),
    ("a scratch path is exempt", "sed -i 's/a/b/' /tmp/x.py", "allow"),
    ("outside any git work tree",
     "sed -i 's/a/b/' /home/iblis/doc/x.py", "allow"),
    ("a documented producer redirect",
     "git log --oneline > %s/CHANGELOG.md" % REPO, "allow"),
    ("remote write is out of scope",
     "ssh host \"sed -i 's/a/b/' /srv/app/x.py\"", "allow"),
]


def verdict(cmd):
    p = subprocess.run(
        [sys.executable, GUARD],
        input=json.dumps({"tool_name": "Bash", "tool_input": {"command": cmd}}),
        capture_output=True, text=True)
    if p.returncode != 0:
        return "CRASH"
    return "DENY" if '"deny"' in p.stdout else "allow"


def main():
    failed = denies = 0
    for label, cmd, want in CASES:
        got = verdict(cmd)
        ok = got == want
        failed += not ok
        denies += got == "DENY"
        print("%s %-52s want=%-5s got=%s" % ("ok  " if ok else "FAIL", label,
                                             want, got))
    print()
    if not denies:
        print("VOID: no case denied, so the guard is failing open and every "
              "'allow' above passed for the wrong reason.")
        return 1
    print("%d/%d passed, %d denials observed (control satisfied)"
          % (len(CASES) - failed, len(CASES), denies))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
