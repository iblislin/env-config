//! PreToolUse deny: refuse a Bash-mediated write to a source file.
//!
//! Behaviour is the Python `bin/claude-src-write-guard`'s, carried across by the
//! differential gate rather than by review -- 76,015 real `(cwd, command)` pairs,
//! 0 disagreements. See `../README.md` for why that gate, and not review, is what
//! authorises this binary to replace the script.
//!
//! WHY THE PANIC HOOK
//! ------------------
//! Measured: a PreToolUse hook that is missing, exits 1, or dies on SIGABRT does
//! NOT block the tool -- only an explicit deny or exit 2 does, and both of those
//! were run as controls. So a panic here would already fail open. The hook is
//! installed anyway, for two reasons: the one variant not measured is a non-2 exit
//! *with* stderr output (which a Rust panic produces), and leaving a question open
//! in the one component that can block every tool call in every session is a poor
//! trade against three lines.
//!
//! Everything else fails open by construction too: unreadable stdin, malformed
//! JSON, a tool that is not Bash, an unreadable cwd. A guard that cannot decide
//! must not decide.

use std::io::Read;

const STAMP: &str = match option_env!("SRC_WRITE_STAMP") {
    Some(s) => s,
    None => "unknown",
};

/// Verbatim from the Python guard's `STEER`. It leads with the runnable
/// replacement because that is the whole intervention: a deny that only says
/// "blocked" costs a turn plus a guess, and the guess is usually another
/// blocked variant.
const STEER: &str = "Bash-mediated writes to source files skip the path-scoped rules under \
.claude/rules/ -- those load on Read, and Bash never triggers one. \
Measured: 40 .py-touching Bash calls in one session produced zero rule \
injections.\n\
Use Read then Edit for an existing file (Edit hard-fails without the Read, \
and that Read is what pulls the rules in), or the Write tool for a new one.\n\
Out of scope, so not this: remote/container writes, targets outside a git \
work tree, generated artifacts, and scratch paths (tmp/, /tmp/, scratchpad, \
.superpowers/).";

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

    if payload.get("tool_name").and_then(|v| v.as_str()) != Some("Bash") {
        return;
    }
    let command = match payload
        .get("tool_input")
        .and_then(|v| v.get("command"))
        .and_then(|v| v.as_str())
    {
        Some(c) if !c.is_empty() => c,
        _ => return,
    };

    // The Python guard reads the process cwd, so this does the same rather than
    // trusting the payload's `cwd` field -- they are normally identical, but the
    // gate compared against the process-cwd behaviour and that is what was
    // proven equivalent.
    let cwd = match std::env::current_dir() {
        Ok(p) => p.to_string_lossy().into_owned(),
        Err(_) => return,
    };

    let (rule, path) = src_write_core::find_write(command, &cwd);
    let (rule, path) = match (rule, path) {
        (Some(r), Some(p)) => (r, p),
        _ => return,
    };

    let out = serde_json::json!({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": format!("Blocked: {rule} write to {path}.\n\n{STEER}"),
        }
    });
    println!("{out}");
}
