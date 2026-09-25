//! PostToolUse hook (TaskCreate|TaskUpdate): mirror the task list to
//! <mirror_dir>/<session_id>.json. See the crate docs for why.

use serde_json::{json, Map, Value};
use std::fs;

const FIELDS: [&str; 4] = ["status", "subject", "description", "activeForm"];

fn run() -> Option<()> {
    let event = task_mirror::read_stdin_json()?;
    let path = task_mirror::mirror_path(event.get("session_id")?.as_str()?)?;
    let input = event.get("tool_input").cloned().unwrap_or(json!({}));

    let mut mirror: Value = fs::read_to_string(&path)
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_else(|| json!({"tasks": {}}));
    let tasks: &mut Map<String, Value> = mirror.get_mut("tasks")?.as_object_mut()?;

    match event.get("tool_name")?.as_str()? {
        "TaskCreate" => {
            let id = id_string(event.pointer("/tool_response/task/id")?)?;
            let text = |k: &str| input.get(k).and_then(Value::as_str).unwrap_or("").to_string();
            tasks.insert(id, json!({"subject": text("subject"),
                                     "description": text("description"),
                                     "status": "pending"}));
        }
        "TaskUpdate" => {
            let id = id_string(input.get("taskId")?)?;
            if input.get("status").and_then(Value::as_str) == Some("deleted") {
                tasks.remove(&id);
            } else if let Some(task) = tasks.get_mut(&id).and_then(Value::as_object_mut) {
                for f in FIELDS {
                    if let Some(v) = input.get(f) {
                        task.insert(f.to_string(), v.clone());
                    }
                }
            }
        }
        _ => return None,
    }

    // Mirror the harness: a list whose tasks are all completed is dropped.
    let all_done = tasks.values().all(|t| t.get("status").and_then(Value::as_str) == Some("completed"));
    if all_done {
        let _ = fs::remove_file(&path);
        return Some(());
    }

    fs::create_dir_all(path.parent()?).ok()?;
    let tmp = path.with_extension(format!("{}", std::process::id()));
    fs::write(&tmp, serde_json::to_string(&mirror).ok()?).ok()?;
    fs::rename(&tmp, &path).ok()
}

/// Task ids arrive as strings, but accept a number too.
fn id_string(v: &Value) -> Option<String> {
    match v {
        Value::String(s) => Some(s.clone()),
        Value::Number(n) => Some(n.to_string()),
        _ => None,
    }
}

fn main() {
    if task_mirror::start() {
        let _ = run();
    }
}
