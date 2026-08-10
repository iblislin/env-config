#!/usr/bin/env bash
# Deterministic tests for the mkgoal wrapper. No API calls: MKGOAL_CLAUDE points
# at a stub that prints a canned response in the sentinel shape, so the whole
# suite runs in milliseconds.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MKGOAL="$HERE/mkgoal"
fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; fails=$((fails + 1)); }

stub="$(mktemp)"
failstub="$(mktemp)"
trap 'rm -f "$stub" "$failstub"' EXIT

cat > "$stub" <<'STUB'
#!/usr/bin/env bash
printf '/goal do the thing. Or stop after 20 turns.\n---MKGOAL-VERDICT---\nSTATUS=pass\nrewrites=0\nboth samples judged correctly\n'
STUB
chmod +x "$stub"

cat > "$failstub" <<'STUB'
#!/usr/bin/env bash
printf '/goal a suspect draft\n---MKGOAL-VERDICT---\nSTATUS=fail\nrewrites=3\njudge kept disagreeing\n'
STUB
chmod +x "$failstub"

out="$(MKGOAL_CLAUDE="$stub" "$MKGOAL" <<< "some intent" 2>/dev/null)"
if [ "$(printf '%s\n' "$out" | grep -c .)" -eq 1 ]; then
    pass "stdout is exactly one line"
else
    fail "stdout was not one line: $out"
fi

case "$out" in
    /goal\ *) pass "stdout starts with '/goal '" ;;
    *)        fail "stdout did not start with '/goal ': $out" ;;
esac

err="$(MKGOAL_CLAUDE="$stub" "$MKGOAL" <<< "some intent" 2>&1 >/dev/null)"
if printf '%s' "$err" | grep -q 'STATUS=pass'; then
    pass "verdict goes to stderr"
else
    fail "verdict missing from stderr: $err"
fi

if printf '%s' "$err" | grep -q '^/goal '; then
    fail "the goal line leaked into stderr"
else
    pass "the goal line does not leak into stderr"
fi

argv_out="$(MKGOAL_CLAUDE="$stub" "$MKGOAL" some intent here 2>/dev/null)"
if [ "$argv_out" = "$out" ]; then
    pass "argv and stdin give the same result"
else
    fail "argv path differs: $argv_out"
fi

MKGOAL_CLAUDE="$stub" "$MKGOAL" </dev/null >/dev/null 2>&1
if [ $? -eq 2 ]; then pass "empty input exits 2"; else fail "empty input did not exit 2"; fi

MKGOAL_CLAUDE="$stub" "$MKGOAL" <<< "   " >/dev/null 2>&1
if [ $? -eq 2 ]; then pass "whitespace-only input exits 2"; else fail "whitespace-only input did not exit 2"; fi

fout="$(MKGOAL_CLAUDE="$failstub" "$MKGOAL" <<< "x" 2>/dev/null)"; frc=$?
if [ "$frc" -eq 1 ]; then pass "STATUS=fail exits 1"; else fail "STATUS=fail exited $frc"; fi
case "$fout" in
    /goal\ *) pass "a failed run still emits the draft on stdout" ;;
    *)        fail "failed run emitted nothing usable: $fout" ;;
esac

# A reply with no sentinel is malformed: surface it whole rather than piping
# something unexpected into the user's buffer.
nosentinel="$(mktemp)"; trap 'rm -f "$stub" "$failstub" "$nosentinel"' EXIT
printf '#!/usr/bin/env bash\nprintf "I think you should probably...\\n"\n' > "$nosentinel"
chmod +x "$nosentinel"
mout="$(MKGOAL_CLAUDE="$nosentinel" "$MKGOAL" <<< "x" 2>/dev/null)"; mrc=$?
if [ "$mrc" -eq 1 ] && [ -z "$mout" ]; then
    pass "a reply with no sentinel exits 1 and emits nothing on stdout"
else
    fail "malformed reply produced rc=$mrc stdout='$mout'"
fi

# A conversational preamble before the /goal line must be dropped, not piped
# into the buffer. Invoking the skill as a slash command produced exactly this
# on 2026-08-10, so the wrapper extracts from the first /goal line onward.
preamble="$(mktemp)"
trap 'rm -f "$stub" "$failstub" "$nosentinel" "$preamble"' EXIT
cat > "$preamble" <<'STUB'
#!/usr/bin/env bash
printf 'Both judges ruled correctly.\n\n/goal the real condition\n---MKGOAL-VERDICT---\nSTATUS=pass\nrewrites=0\njudge_model=claude-haiku-4-5-20251001\nfine\n'
STUB
chmod +x "$preamble"
pout="$(MKGOAL_CLAUDE="$preamble" "$MKGOAL" <<< "x" 2>/dev/null)"
if [ "$pout" = "/goal the real condition" ]; then
    pass "a preamble before the /goal line is dropped from stdout"
else
    fail "preamble leaked into stdout: '$pout'"
fi

noglob="$(mktemp)"
trap 'rm -f "$stub" "$failstub" "$nosentinel" "$preamble" "$noglob"' EXIT
printf '#!/usr/bin/env bash\nprintf "chatter only, no condition\\n---MKGOAL-VERDICT---\\nSTATUS=pass\\n"\n' > "$noglob"
chmod +x "$noglob"
gout="$(MKGOAL_CLAUDE="$noglob" "$MKGOAL" <<< "x" 2>/dev/null)"; grc=$?
if [ "$grc" -eq 1 ] && [ -z "$gout" ]; then
    pass "a reply with no /goal line exits 1 and emits nothing"
else
    fail "missing /goal line gave rc=$grc stdout='$gout'"
fi

# The judge-model check: a run judged by something other than haiku is stricter
# than the live evaluator, so it can pass a condition that then stalls a real
# goal. The warning must fire on absence, and must not fire on a good run.
werr="$(MKGOAL_CLAUDE="$stub" "$MKGOAL" <<< "x" 2>&1 >/dev/null)"
if printf '%s' "$werr" | grep -q 'WARNING: judges were not confirmed'; then
    pass "missing judge_model raises the warning"
else
    fail "no warning when judge_model is absent"
fi

haikustub="$(mktemp)"
trap 'rm -f "$stub" "$failstub" "$nosentinel" "$haikustub"' EXIT
cat > "$haikustub" <<'STUB'
#!/usr/bin/env bash
printf '/goal a proven draft\n---MKGOAL-VERDICT---\nSTATUS=pass\nrewrites=0\njudge_model=claude-haiku-4-5-20251001\nboth judged correctly\n'
STUB
chmod +x "$haikustub"
herr="$(MKGOAL_CLAUDE="$haikustub" "$MKGOAL" <<< "x" 2>&1 >/dev/null)"
if printf '%s' "$herr" | grep -q 'WARNING'; then
    fail "warning fired even though judge_model names haiku: $herr"
else
    pass "a haiku judge_model raises no warning"
fi

if [ "$fails" -ne 0 ]; then
    printf '\n%d check(s) failed\n' "$fails"
    exit 1
fi
printf '\nall checks passed\n'
