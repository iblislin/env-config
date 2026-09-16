//! PreToolUse deny: port of the Python `bin/claude-warning-sign-guard`.
//!
//! Behaviour is the Python script's, carried across by the `hook-diff`
//! differential gate rather than by review -- see `../.warn-sign-port-report.md`
//! for the verdict counts that authorise this binary. `hook-diff` gates at the
//! PROCESS level (payload in, (blocking?, parsed stdout) out) rather than at a
//! single function, because this guard has no pure-function seam: for a `Write`
//! it ALSO READS THE TARGET FILE FROM DISK to count pre-existing occurrences,
//! so the verdict genuinely depends on filesystem state.
//!
//! THE WARNING SIGN IS WRITTEN AS AN ESCAPE, NEVER AS THE GLYPH
//! --------------------------------------------------------------
//! `SIGN` and `VS16` below are `\u{26A0}` / `\u{FE0F}` escapes, not the literal
//! characters. A Rust source file containing the raw glyph would be refused by
//! this very guard the next time anyone edits it -- CODE_EXT covers `.rs`, and
//! the comment/prose distinction does not save a `const` initializer holding
//! the bare character. The Python original can use the literal glyph because it
//! predates this port and is explicitly out of the "legacy is not swept" scope;
//! this file has no such exemption to inherit.
//!
//! MATCHED BUG-FOR-BUG -- do not "fix" any of these while touching this file
//! ---------------------------------------------------------------------------
//! * `Edit`'s `before` count is a bare `WARN` match count over `old_string`
//!   (no fence/blockquote/comment filtering); `after` runs `old_string`'s
//!   sibling `new_string` through the full `prose_hits` treatment. The two
//!   sides are deliberately asymmetric -- an `old_string` quoting the symbol
//!   inside a fenced block still counts toward `before`.
//! * `classify` returns three states, and `None` ("out of scope") is not the
//!   same as `Some(false)` ("whole file is prose"): only `Write`/`Edit` on an
//!   extension this guard recognises produces a verdict at all.
//! * The recorded hit text is the STRIPPED line (`line`), while the text tested
//!   for a match is the RAW line or the comment's captured group (`candidate`).
//!   They are not unified.
//! * Fence/comment detection runs over the ADDED text only -- an `Edit` landing
//!   inside a fence or block comment opened earlier in the file reads as
//!   ordinary prose (or ordinary code) and is judged on that basis. This
//!   over-refuses rather than under-refuses, which is the direction the
//!   original accepted.
//!
//! WHY THE PANIC HOOK
//! ------------------
//! Same rationale as `src-write-guard`: everything here fails open by
//! construction (unreadable stdin, malformed JSON, an unrecognised tool), and
//! the panic hook covers the one case that is not otherwise measured -- a
//! non-2 exit that carries stderr, which is what a Rust panic produces without
//! it. A guard that cannot decide must not decide.

use regex::Regex;
use std::io::Read as _;
use std::sync::LazyLock;

const STAMP: &str = match option_env!("SRC_WRITE_STAMP") {
    Some(s) => s,
    None => "unknown",
};

// The warning sign, U+26A0, and VARIATION SELECTOR-16 (U+FE0F), which selects
// the emoji-style presentation. Written as escapes -- see the module doc.
const SIGN: char = '\u{26A0}';
const VS16: char = '\u{FE0F}';

static WARN: LazyLock<Regex> = LazyLock::new(|| {
    let pat = format!("{SIGN}{VS16}?");
    Regex::new(&pat).unwrap()
});

// Markdown-ish: the whole file is prose.
static PROSE_EXT: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)\.(md|markdown|mdx|rst|txt|adoc)$").unwrap());
static PROSE_NAME: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(^|/)(AGENTS|CLAUDE|README|SKILL|CHANGELOG)\.md$").unwrap()
});
// Source: only comment text is inspected.
static CODE_EXT: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"(?i)\.(ts|tsx|js|jsx|mjs|cjs|py|pyi|go|rs|java|kt|scala|sh|bash|zsh|rb|c|h|\
cc|cpp|hpp|sql|yml|yaml|toml|tf|vue|css|scss|html)$",
    )
    .unwrap()
});
// One-line and block comment openers, enough for the languages above.
static COMMENT: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(//|#|/\*|\*|--|<!--|;)\s*(?P<text>.*)$").unwrap());

static BACKTICK: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"`[^`]*`").unwrap());

static BASH_TEXT_WRITE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r#"(?i)(>>?|\btee\b)\s*["']?([^\s"'|;&]+\.(?:md|markdown|mdx|rst|txt|adoc|ts|tsx|js|py|go|rs|java|sh|yml|yaml|toml|sql|css|scss|html))"#,
    )
    .unwrap()
});

const MESSAGE_PREFIX: &str = "Drop the warning sign and move the emphasis into an opening bold clause:\n      **A guard may be doing a second job nobody wrote down, and this is the trap in the rule.**\nIt buys nothing, and attention decays anyway once the context is long (the user's own words, in this project's review notes). Legacy occurrences are NOT being swept — only newly written prose, which is why this refuses a net increase and not its mere presence. To write ABOUT the symbol, put it in a backtick span, a fenced block, or a blockquote line; in source, only comment text is inspected at all.\n";

const BASH_EXTRA: &str = "Also: this writes a file through the shell, where a Write/Edit matcher cannot see it. Use the Write or Edit tool instead — see CLAUDE.md § Write files with Write / Edit, not through Bash.";

fn message(extra: &str) -> String {
    format!("{MESSAGE_PREFIX}{extra}")
}

/// Remove backtick spans -- the documented way to write about the symbol.
fn strip_escapes(line: &str) -> String {
    BACKTICK.replace_all(line, "").into_owned()
}

/// Occurrences in `text` that are emphasis rather than subject matter.
///
/// `code_only == true` means only comment text is inspected at all (source
/// file); `code_only == false` means the whole file is prose (markdown-ish),
/// with fenced blocks and blockquote lines excluded.
fn prose_hits(text: &str, code_only: bool) -> Vec<String> {
    let mut hits = Vec::new();
    let mut in_fence = false;
    for raw in text.split('\n') {
        let line = raw.trim();
        let candidate: &str = if !code_only {
            if line.starts_with("```") || line.starts_with("~~~") {
                in_fence = !in_fence;
                continue;
            }
            if in_fence || line.starts_with('>') {
                continue;
            }
            raw
        } else {
            match COMMENT.captures(raw) {
                None => continue, // not a comment: code, literals, regexes
                Some(caps) => match caps.name("text") {
                    Some(m) => m.as_str(),
                    None => continue,
                },
            }
        };
        if WARN.is_match(&strip_escapes(candidate)) {
            let clipped: String = line.chars().take(90).collect();
            hits.push(clipped);
        }
    }
    hits
}

/// `false` = whole file is prose, `true` = comments only, `None` = out of
/// scope (return without deciding). `None` is not `Some(false)`.
fn classify(path: &str) -> Option<bool> {
    if PROSE_EXT.is_match(path) || PROSE_NAME.is_match(path) {
        return Some(false);
    }
    if CODE_EXT.is_match(path) {
        return Some(true);
    }
    None
}

/// Minimal `os.path.expanduser` equivalent: only the `~` and `~/...` forms
/// this guard's inputs actually use. `~user` is left untouched, same as the
/// Python original would be for an unresolvable pwd lookup on this host.
fn expanduser(p: &str) -> String {
    let home = std::env::var("HOME").ok();
    if p == "~" {
        return home.unwrap_or_else(|| p.to_string());
    }
    if let Some(rest) = p.strip_prefix("~/") {
        if let Some(h) = home {
            return format!("{}/{}", h.trim_end_matches('/'), rest);
        }
    }
    p.to_string()
}

fn str_field<'a>(inp: &'a serde_json::Value, key: &str) -> &'a str {
    inp.get(key).and_then(|v| v.as_str()).unwrap_or("")
}

/// `Edit`/`Write` branch. Returns the deny reason, if any.
fn check_write_like(tool: &str, inp: &serde_json::Value) -> Option<String> {
    let file_path = str_field(inp, "file_path");
    let code_only = classify(file_path)?; // None -> out of scope, no verdict

    let (before, after) = if tool == "Edit" {
        let old_string = str_field(inp, "old_string");
        let new_string = str_field(inp, "new_string");
        let before = WARN.find_iter(old_string).count();
        let after = prose_hits(new_string, code_only);
        (before, after)
    } else {
        let content = str_field(inp, "content");
        let after = prose_hits(content, code_only);
        // Fail-to-zero on any read problem, exactly like the Python
        // `except (OSError, KeyError): before = 0` -- an unreadable or
        // missing file (including a missing `file_path` key, folded into
        // `str_field`'s empty-string default here) is not grounds to deny.
        let before = if file_path.is_empty() {
            0
        } else {
            match std::fs::read_to_string(expanduser(file_path)) {
                Ok(text) => WARN.find_iter(&text).count(),
                Err(_) => 0,
            }
        };
        (before, after)
    };

    if after.len() > before {
        Some(message(&format!("Introduced on: {}", after[0])))
    } else {
        None
    }
}

/// `Bash` branch. Returns the deny reason, if any.
fn check_bash(inp: &serde_json::Value) -> Option<String> {
    let cmd = str_field(inp, "command");
    if WARN.is_match(cmd) && BASH_TEXT_WRITE.is_match(cmd) {
        Some(message(BASH_EXTRA))
    } else {
        None
    }
}

fn deny(reason: &str) {
    let out = serde_json::json!({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    });
    println!("{out}");
}

fn main() {
    // Fail open on panic: exit 0 quietly rather than letting a stderr-carrying
    // abort reach the harness with an unmeasured exit status.
    std::panic::set_hook(Box::new(|_| std::process::exit(0)));

    if std::env::args().any(|a| a == "--stamp") {
        println!("{STAMP}");
        return;
    }

    let mut raw = String::new();
    if std::io::stdin().read_to_string(&mut raw).is_err() {
        return;
    }
    let payload: serde_json::Value = match serde_json::from_str(&raw) {
        Ok(v) => v,
        Err(_) => return,
    };

    let tool = payload
        .get("tool_name")
        .and_then(|v| v.as_str())
        .unwrap_or("");
    let empty = serde_json::Value::Object(Default::default());
    let inp = payload.get("tool_input").unwrap_or(&empty);

    let reason = match tool {
        "Edit" | "Write" => check_write_like(tool, inp),
        "Bash" => check_bash(inp),
        _ => None,
    };
    if let Some(reason) = reason {
        deny(&reason);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // --- prose_hits: fences ---------------------------------------------

    #[test]
    fn prose_hits_flags_bare_occurrence() {
        let text = format!("plain text {SIGN} more text");
        let hits = prose_hits(&text, false);
        assert_eq!(hits.len(), 1);
    }

    #[test]
    fn prose_hits_skips_inside_fenced_block() {
        let text = format!("```\nsome code {SIGN} here\n```\nafter fence {SIGN}");
        let hits = prose_hits(&text, false);
        // Only the line after the fence closes should count.
        assert_eq!(hits.len(), 1);
        assert!(hits[0].contains("after fence"));
    }

    #[test]
    fn prose_hits_tilde_fence_also_toggles() {
        let text = format!("~~~\n{SIGN}\n~~~");
        let hits = prose_hits(&text, false);
        assert!(hits.is_empty());
    }

    // --- prose_hits: blockquote ------------------------------------------

    #[test]
    fn prose_hits_skips_blockquote_line() {
        let text = format!("> quoted {SIGN} line\nnormal {SIGN} line");
        let hits = prose_hits(&text, false);
        assert_eq!(hits.len(), 1);
        assert!(hits[0].contains("normal"));
    }

    // --- prose_hits: backtick escape -------------------------------------

    #[test]
    fn prose_hits_skips_backtick_span() {
        let text = format!("discussing `{SIGN}` in prose");
        let hits = prose_hits(&text, false);
        assert!(hits.is_empty());
    }

    #[test]
    fn prose_hits_still_flags_outside_backtick_span() {
        let text = format!("discussing `the symbol` {SIGN} for real");
        let hits = prose_hits(&text, false);
        assert_eq!(hits.len(), 1);
    }

    // --- prose_hits: code_only / comment filtering ------------------------

    #[test]
    fn prose_hits_code_only_ignores_non_comment_line() {
        // No comment-opener character (`//`, `#`, `/*`, `*`, `--`, `<!--`,
        // `;`) anywhere in this line, so COMMENT never matches at all and the
        // line is skipped outright regardless of what it contains.
        let text = format!("let msg = format!(\"plain {SIGN} value\")");
        let hits = prose_hits(&text, true);
        assert!(hits.is_empty());
    }

    #[test]
    fn prose_hits_code_only_flags_line_comment() {
        let text = format!("// heads up {SIGN} here");
        let hits = prose_hits(&text, true);
        assert_eq!(hits.len(), 1);
    }

    #[test]
    fn prose_hits_code_only_backtick_escape_in_comment() {
        let text = format!("# discussing `{SIGN}` in a comment");
        let hits = prose_hits(&text, true);
        assert!(hits.is_empty());
    }

    #[test]
    fn prose_hits_code_only_does_not_apply_fence_rule() {
        // Fence/blockquote handling is markdown-only; a source line that
        // happens to start with "```" is not a recognised comment opener and
        // is simply skipped as non-comment code, not toggled as a fence.
        let text = format!("```{SIGN}\n// real hit {SIGN}");
        let hits = prose_hits(&text, true);
        assert_eq!(hits.len(), 1);
    }

    // --- classify: three states -------------------------------------------

    #[test]
    fn classify_prose_extension_is_some_false() {
        assert_eq!(classify("notes/README.md"), Some(false));
    }

    #[test]
    fn classify_prose_name_without_prose_extension_scope() {
        // CLAUDE.md matches PROSE_NAME even though it also matches
        // PROSE_EXT; the important thing is the state, not which regex hit.
        // Neutral home path on purpose: this repository is public, and a real
        // username in a fixture is a detail the test does not need.
        assert_eq!(classify("/home/u/.claude/CLAUDE.md"), Some(false));
    }

    #[test]
    fn classify_code_extension_is_some_true() {
        assert_eq!(classify("src/main.rs"), Some(true));
    }

    #[test]
    fn classify_unknown_extension_is_none() {
        assert_eq!(classify("data/table.parquet"), None);
        assert_eq!(classify("no-extension-at-all"), None);
    }
}
