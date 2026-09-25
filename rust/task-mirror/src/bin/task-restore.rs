//! SessionStart hook: hand the model the open tasks mirrored for this session,
//! so it can rebuild the list a new agent-teams team started without.

use serde_json::{json, Value};

const PREAMBLE: &str = "Task list carried over from before this harness start, recorded for this \
session by the user's own claude-task-mirror hook (with agent-teams on, a restart starts a new, \
empty list). Call TaskList first; if these are not there, recreate only the missing ones with \
TaskCreate and set their status with TaskUpdate. IDs will be renumbered.\n";

fn run() -> Option<()> {
    let event = task_mirror::read_stdin_json()?;
    // clear starts a new session id (nothing mirrored under it); compact keeps
    // the process and its team, so the harness list is still intact.
    if !matches!(event.get("source")?.as_str()?, "resume" | "startup") {
        return None;
    }
    let path = task_mirror::mirror_path(event.get("session_id")?.as_str()?)?;
    let mirror: Value = serde_json::from_str(&std::fs::read_to_string(path).ok()?).ok()?;

    let lines: Vec<String> = mirror
        .get("tasks")?
        .as_object()?
        .iter()
        .filter_map(|(id, t)| {
            let status = t.get("status")?.as_str()?;
            (status != "completed").then(|| {
                format!("#{id} [{status}] {}", t.get("subject").and_then(Value::as_str).unwrap_or(""))
            })
        })
        .collect();
    if lines.is_empty() {
        return None;
    }
    let out = json!({"hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": format!("{PREAMBLE}{}", lines.join("\n")),
    }});
    println!("{out}");
    Some(())
}

fn main() {
    if task_mirror::start() {
        let _ = run();
    }
}
