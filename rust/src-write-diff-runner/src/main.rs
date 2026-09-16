//! Batch runner for the differential gate.
//!
//! Reads corpus JSONL on stdin (`{"cwd": "...", "command": "..."}` per line),
//! writes verdict JSONL on stdout (`{"rule": ... , "path": ...}`), one line out
//! per line in, **in order**. The harness compares positionally, so dropping or
//! reordering a row silently misaligns every verdict after it -- hence the
//! strict one-to-one contract and the harness's own length check.
//!
//! One process for the whole corpus, not one per command: at 76k rows a
//! per-command spawn is ~20s of pure exec overhead, and a check that is slow to
//! run stops being run.
//!
//! `--stamp` prints the source revision this binary was built from, which is
//! how `make check-stamp` detects a binary that predates the working tree.

use std::io::{self, BufRead, Write};

/// Injected by the Makefile at build time. `unknown` means someone built with
/// bare `cargo build`, which is itself worth seeing in the staleness check.
const STAMP: &str = match option_env!("SRC_WRITE_STAMP") {
    Some(s) => s,
    None => "unknown",
};

fn main() {
    if std::env::args().any(|a| a == "--stamp") {
        println!("{STAMP}");
        return;
    }

    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut out = io::BufWriter::new(stdout.lock());

    for line in stdin.lock().lines() {
        let line = match line {
            Ok(l) => l,
            Err(e) => {
                eprintln!("read error: {e}");
                std::process::exit(2);
            }
        };
        if line.trim().is_empty() {
            continue;
        }
        let row: serde_json::Value = match serde_json::from_str(&line) {
            Ok(v) => v,
            Err(e) => {
                eprintln!("bad corpus line: {e}");
                std::process::exit(2);
            }
        };
        let cwd = row.get("cwd").and_then(|v| v.as_str()).unwrap_or("/");
        let cmd = row.get("command").and_then(|v| v.as_str()).unwrap_or("");

        // The Python side chdir()s per row because `find_write` reads the
        // process cwd. Here the cwd is passed explicitly instead: a global
        // chdir would be a data race the moment this is parallelised, and the
        // explicit form is what the eventual hook binary wants anyway.
        //
        // A recorded cwd can name a worktree that has since been deleted, and
        // the Python harness cannot chdir there either -- `verdict_python`
        // falls back to "/" for exactly that case. Apply the SAME fallback in
        // the SAME layer, so the two sides are handed identical inputs and
        // `find_write` keeps its "cwd exists" contract. "/" is chosen because
        // it always exists and is never inside a git work tree, so it cannot
        // make an unresolvable target look resolvable.
        let cwd = if std::path::Path::new(cwd).is_dir() { cwd } else { "/" };

        let (rule, path) = src_write_core::find_write(cmd, cwd);

        let v = serde_json::json!({ "rule": rule, "path": path });
        if writeln!(out, "{v}").is_err() {
            std::process::exit(2);
        }
    }
    let _ = out.flush();
}
