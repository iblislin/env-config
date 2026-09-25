//! Shared pieces of the task-list mirror hooks (a port of
//! `~/.claude/tools/claude-task-mirror` and `claude-task-restore`).
//!
//! With agent-teams on, the task list belongs to the TEAM, and every harness
//! launch mints a new team, so a restart starts an empty list while the old
//! files sit orphaned on disk (measured 2026-09-25). The harness records no
//! session -> team mapping; the session id is the only durable key, so the
//! PostToolUse half mirrors the list under it and the SessionStart half hands
//! the open tasks back to the model.
//!
//! Both binaries fail open: a panic or any error exits 0 with no output.
//! Behaviour is pinned by the black-box suite at
//! `~/.claude/tests/task-mirror/test_task_mirror.py`, run against these
//! binaries with TASK_MIRROR_BIN / TASK_RESTORE_BIN.

use std::path::PathBuf;

pub const STAMP: &str = match option_env!("SRC_WRITE_STAMP") {
    Some(s) => s,
    None => "unstamped",
};

/// Common prologue: fail open on panic, and answer `--stamp`.
/// Returns false when the caller should exit immediately.
pub fn start() -> bool {
    std::panic::set_hook(Box::new(|_| std::process::exit(0)));
    if std::env::args().any(|a| a == "--stamp") {
        println!("{STAMP}");
        return false;
    }
    true
}

pub fn mirror_dir() -> PathBuf {
    match std::env::var_os("CLAUDE_TASK_MIRROR_DIR") {
        Some(d) => PathBuf::from(d),
        None => {
            let home = std::env::var_os("HOME").unwrap_or_default();
            PathBuf::from(home).join(".claude/tmux-status/tasks")
        }
    }
}

/// The mirror file for a session, or None when the id could escape the
/// directory (anything but ASCII alphanumerics and '-').
pub fn mirror_path(sid: &str) -> Option<PathBuf> {
    if sid.is_empty() || !sid.chars().all(|c| c.is_ascii_alphanumeric() || c == '-') {
        return None;
    }
    Some(mirror_dir().join(format!("{sid}.json")))
}

pub fn read_stdin_json() -> Option<serde_json::Value> {
    let mut buf = String::new();
    std::io::Read::read_to_string(&mut std::io::stdin(), &mut buf).ok()?;
    serde_json::from_str(&buf).ok()
}
