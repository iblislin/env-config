//! PostToolUse hook (TaskCreate only): carry the open tasks of this
//! conversation's previous agent-teams team into its current one. A port of
//! `~/.claude/tools/claude-task-carry`; behaviour is pinned by the black-box
//! suite `~/.claude/tests/task-carry/test_task_carry.py`, run against this
//! binary with TASK_CARRY_BIN.
//!
//! The task list lives in the TEAM's dir, `~/.claude/tasks/session-<team>/`,
//! and a new, empty team is minted on a harness restart and when a session is
//! sent to the background -- which also changes the session id (both measured
//! 2026-09-25). The key that survives both is the uuid of the transcript's
//! first record. `TaskList` reads the dir from disk and new ids skip existing
//! files, so copying the harness's own files (changing only `id`) is enough.
//!
//! Only a freshly written task file reveals which dir is the current team:
//! hook stdin carries no team id, and two teams have been seen minted in the
//! same second. Fails open: a panic or any error exits 0 with no output.

use serde_json::Value;
use std::fs;
use std::io::{BufRead, BufReader, Read};
use std::path::{Path, PathBuf};

const STAMP: &str = match option_env!("SRC_WRITE_STAMP") {
    Some(s) => s,
    None => "unstamped",
};

fn home_join(rel: &str) -> PathBuf {
    PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(rel)
}

fn env_dir(var: &str, default: &str) -> PathBuf {
    std::env::var_os(var).map(PathBuf::from).unwrap_or_else(|| home_join(default))
}

fn is_safe_key(s: &str) -> bool {
    !s.is_empty() && s.chars().all(|c| c.is_ascii_alphanumeric() || c == '-')
}

/// The uuid of the transcript's first record that has one; None when unsafe.
fn conversation_key(transcript: &Path) -> Option<String> {
    let reader = BufReader::new(fs::File::open(transcript).ok()?);
    for line in reader.lines() {
        let rec: Value = serde_json::from_str(&line.ok()?).ok()?;
        if let Some(uuid) = rec.get("uuid").and_then(Value::as_str) {
            return is_safe_key(uuid).then(|| uuid.to_string());
        }
    }
    None
}

fn read_task(path: &Path) -> Option<Value> {
    serde_json::from_str(&fs::read_to_string(path).ok()?).ok()
}

/// The team dir holding the task just created: `<tid>.json` with this subject,
/// newest by mtime.
fn current_team(tasks_dir: &Path, tid: &str, subject: &str) -> Option<PathBuf> {
    let mut best: Option<(std::time::SystemTime, PathBuf)> = None;
    for entry in fs::read_dir(tasks_dir).ok()?.flatten() {
        let dir = entry.path();
        let file = dir.join(format!("{tid}.json"));
        let Some(task) = read_task(&file) else { continue };
        if task.get("subject").and_then(Value::as_str) != Some(subject) {
            continue;
        }
        let Ok(mtime) = file.metadata().and_then(|m| m.modified()) else { continue };
        if best.as_ref().map_or(true, |(t, _)| mtime > *t) {
            best = Some((mtime, dir));
        }
    }
    best.map(|(_, d)| d)
}

/// Numbered task files in a team dir, as (id, path), sorted by id.
fn task_files(team: &Path) -> Vec<(u64, PathBuf)> {
    let mut out: Vec<(u64, PathBuf)> = fs::read_dir(team)
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|e| {
            let p = e.path();
            let stem = p.file_stem()?.to_str()?;
            (p.extension()? == "json").then_some(())?;
            Some((stem.parse().ok()?, p))
        })
        .collect();
    out.sort();
    out
}

/// Copy `old`'s open tasks into `new`, numbered after `new`'s current max.
fn carry(old: &Path, new: &Path) {
    let mut next = task_files(new).last().map_or(0, |(id, _)| *id) + 1;
    for (_, src) in task_files(old) {
        let Some(mut task) = read_task(&src) else { continue };
        if task.get("status").and_then(Value::as_str) == Some("completed") {
            continue;
        }
        task["id"] = Value::String(next.to_string());
        if fs::write(new.join(format!("{next}.json")), task.to_string()).is_ok() {
            next += 1;
        }
    }
}

fn run() -> Option<()> {
    let mut buf = String::new();
    std::io::stdin().read_to_string(&mut buf).ok()?;
    let event: Value = serde_json::from_str(&buf).ok()?;
    let tasks_dir = env_dir("CLAUDE_TASKS_DIR", ".claude/tasks");
    let state_dir = env_dir("CLAUDE_TASK_CARRY_DIR", ".claude/tmux-status/task-carry");

    let key = conversation_key(Path::new(event.get("transcript_path")?.as_str()?))?;
    // Only TaskCreate identifies the team: its response carries the subject.
    // TaskUpdate carries only an id, and the newest <id>.json across all teams
    // can belong to another live session -- trusting it swapped tasks between
    // two conversations (incident 2026-09-25).
    if event.get("tool_name")?.as_str()? != "TaskCreate" {
        return None;
    }
    let task = event.get("tool_response")?.get("task")?;
    let team = current_team(&tasks_dir, &id_str(task.get("id")?)?, task.get("subject")?.as_str()?)?;

    let record = state_dir.join(format!("{key}.team"));
    if let Ok(prev) = fs::read_to_string(&record) {
        let prev = PathBuf::from(prev.trim());
        if prev != team {
            carry(&prev, &team);
        }
    }
    fs::create_dir_all(&state_dir).ok()?;
    fs::write(&record, format!("{}\n", team.display())).ok()
}

fn id_str(v: &Value) -> Option<String> {
    match v {
        Value::String(s) => Some(s.clone()),
        Value::Number(n) => Some(n.to_string()),
        _ => None,
    }
}

fn main() {
    std::panic::set_hook(Box::new(|_| std::process::exit(0)));
    if std::env::args().any(|a| a == "--stamp") {
        println!("{STAMP}");
        return;
    }
    let _ = run();
}
