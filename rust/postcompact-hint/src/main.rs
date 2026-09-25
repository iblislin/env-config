//! SessionStart hook (source=compact): after a compaction that followed a
//! mem-handover, tell the model it was just compacted and to read the handover.
//! A port of `~/.claude/tools/claude-postcompact-hint`; behaviour is pinned by
//! `~/.claude/tests/postcompact-hint/test_postcompact_hint.py`, run against this
//! binary with POSTCOMPACT_HINT_BIN.
//!
//! SessionStart, not PostCompact: measured 2026-09-25 on claude 2.1.281,
//! PostCompact's additionalContext is reported as a failed hook and reaches the
//! model only by leaking into `/compact`'s command output, so it vanishes on an
//! auto-compact. The handover's path is not tracked -- the agent keeps writing
//! files between handover and compaction -- so the hint names MEMORY.md's newest
//! HANDOVER entry, which every session loads.
//!
//! State is `<CLAUDE_CTX_DIR>/<session_id>.state`, shared with
//! claude-context-pct (`done` = the mem-handover Skill ran; it drops `hinted`
//! when it re-arms). Fails open: a panic or any error exits 0 with no output.

use serde_json::{json, Value};
use std::fs;
use std::io::Read;
use std::path::PathBuf;

const STAMP: &str = match option_env!("SRC_WRITE_STAMP") {
    Some(s) => s,
    None => "unstamped",
};

const HINT: &str = "This session was just compacted. Before that, you ran mem-handover: the \
handover is the newest HANDOVER entry in MEMORY.md (auto-memory). The compaction summary above \
does not replace it -- read that handover file before continuing the task.";

fn ctx_dir() -> PathBuf {
    std::env::var_os("CLAUDE_CTX_DIR").map(PathBuf::from).unwrap_or_else(|| {
        PathBuf::from(std::env::var_os("HOME").unwrap_or_default())
            .join(".claude/tmux-status/ctx")
    })
}

fn run() -> Option<()> {
    let mut buf = String::new();
    std::io::stdin().read_to_string(&mut buf).ok()?;
    let event: Value = serde_json::from_str(&buf).ok()?;
    if event.get("source")?.as_str()? != "compact" {
        return None;
    }
    let sid = event.get("session_id")?.as_str()?;
    if sid.is_empty() || !sid.chars().all(|c| c.is_ascii_alphanumeric() || c == '-') {
        return None;
    }
    let path = ctx_dir().join(format!("{sid}.state"));
    let mut state: Value = serde_json::from_str(&fs::read_to_string(&path).ok()?).ok()?;
    if state.get("done") != Some(&Value::Bool(true))
        || state.get("hinted").and_then(Value::as_bool).unwrap_or(false)
    {
        return None;
    }
    state.as_object_mut()?.insert("hinted".into(), Value::Bool(true));
    let tmp = path.with_extension(format!("{}", std::process::id()));
    fs::write(&tmp, state.to_string()).ok()?;
    fs::rename(&tmp, &path).ok()?;
    let out = json!({"hookSpecificOutput": {
        "hookEventName": "SessionStart", "additionalContext": HINT}});
    println!("{out}");
    Some(())
}

fn main() {
    std::panic::set_hook(Box::new(|_| std::process::exit(0)));
    if std::env::args().any(|a| a == "--stamp") {
        println!("{STAMP}");
        return;
    }
    let _ = run();
}
