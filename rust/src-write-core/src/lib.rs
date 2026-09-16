//! Port of `bin/claude-src-write-guard`'s decision function.
//!
//! THE CONTRACT
//! ------------
//! `find_write(command, cwd) -> (Option<rule>, Option<path>)` must return the
//! same pair the Python `find_write(cmd)` returns when run with that `cwd` as
//! the process working directory. Same rule name, same absolute path, on every
//! input -- including the inputs where the Python one is arguably wrong.
//!
//! **Match it bug-for-bug.** The guard's behaviour is an unwritten
//! specification earned over a documented 39%-to-near-zero false-positive
//! history, and the differential gate is the only thing that carries it across.
//! A port that "fixes" something on the way through makes the gate red and,
//! worse, makes a real regression indistinguishable from a deliberate
//! improvement. Improvements land afterwards, in both implementations, with the
//! gate green in between.
//!
//! Verify with `make gate` from the workspace root. The bar is 0 disagreements
//! over every corpus row, and the harness refuses to call an empty or
//! never-firing run a pass.
//!
//! FOUR HAND-CODED SCANNERS
//! ------------------------
//! The `regex` crate has no lookaround and no backreferences. Four Python
//! constructs need one or the other, so each gets a small hand-written scanner
//! instead of a regex:
//!
//! 1. `HEREDOC` (line 120 of the guard): `(?P<tag>...)\1 ... (?P=tag)` -- a
//!    heredoc body runs until a line that equals the opening tag. See
//!    `find_heredocs`.
//! 2. the `python3 -c '...'` body (line 150): `(['"])(.*?)\1` -- quoted with a
//!    matching quote character. See `find_dash_c_bodies` with `PY_C_PREFIX`.
//! 3. the `bash -c '...'` body (line 156): same shape, narrower interpreter
//!    set. See `find_dash_c_bodies` with `SHELL_WRAPPER_PREFIX`.
//! 4. the shell redirect (lines 195, 232): `(?<!\\)>>?` -- a redirect that is
//!    NOT an escaped `\>` (POSIX `[ $a \> $b ]` string comparison). See
//!    `find_redirects`.
//!
//! Everything else below is a direct translation: no lookaround, no
//! backreferences, so the `regex` crate expresses it exactly as the Python
//! `re` pattern did.
//!
//! `in_git_tree` keeps the `git -C <dir> rev-parse --is-inside-work-tree`
//! subprocess rather than hand-rolling a `.git` walk. On this machine `.git` is
//! frequently a FILE (git worktrees), and a walk that assumes a directory is
//! wrong only there -- correctness first, and it only runs on survivors.

use regex::{Captures, Regex};
use std::collections::HashMap;
use std::sync::LazyLock;

// --- extensions --------------------------------------------------------------

const SOURCE_EXT: &str = "py|ts|tsx|js|mjs|cjs|scala|java|sh|bash|zsh|\
md|rst|less|css|scss|pug|html|\
yaml|yml|json|toml|graphql|gql|sql|jinja2|properties|\
tex|cls|sty|bib|dtx|ins|typ|Rmd|qmd";

fn ext_re() -> &'static str {
    SOURCE_EXT
}

// --- ASCII whitespace, matching Python's `\s` on ASCII shell text ----------
//
// `u8::is_ascii_whitespace()` omits vertical tab (0x0B), which Python's `\s`
// includes. Shell text essentially never carries a literal VT, but this keeps
// the two definitions aligned rather than silently drifting.
fn is_ws(b: u8) -> bool {
    matches!(b, b' ' | b'\t' | b'\n' | b'\r' | 0x0b | 0x0c)
}

// --- top-level guards ---------------------------------------------------------

static REMOTE_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*(?:sudo\s+)?(?:ssh|scp|rsync)\b|\b(?:docker|podman|kubectl)\s+(?:compose\s+)?exec\b")
        .unwrap()
});

const GENERATOR: &[&str] = &[
    "git", "curl", "wget", "jq", "yq", "docker", "kubectl", "helm", "glab", "gh", "npm", "yarn",
    "pnpm", "poetry", "pip", "pip3", "make", "cargo", "go", "sbt", "mvn", "gradle", "pytest",
    "ruff", "black", "mypy", "openssl", "base64", "sha256sum", "md5sum", "find", "ls", "env",
    "printenv", "date", "uname", "ps", "df", "du", "systemctl", "journalctl", "dmesg",
    "kafka-topics.sh",
];

static EXEMPT_PATH_RE: LazyLock<Regex> = LazyLock::new(|| {
    // NOTE: this must stay a single raw-string line. `r"...\<newline>"` inside
    // a raw string is NOT a line-continuation escape (that only exists for
    // normal, non-raw string literals) -- splitting this across lines with a
    // trailing backslash previously embedded a literal backslash + newline
    // into the pattern, corrupting the alternation and making the guard
    // massively over-fire (measured: 675 vs the baseline's 359 on the real
    // corpus, all of it `.superpowers/` paths that should have been exempt).
    Regex::new(r"(^|/)(tmp|scratchpad|\.superpowers|node_modules|\.git|__pycache__|dist|build|target|out|\.cache|\.venv|venv|site-packages|coverage|htmlcov|\.next|\.nuxt|\.svelte-kit|\.pytest_cache|\.mypy_cache)(/|$)|^/tmp/|^/var/tmp/|/\.claude/projects/")
    .unwrap()
});

// --- context splitting -------------------------------------------------------

/// One heredoc occurrence: `start`/`end` mirror Python's `m.start()`/`m.end()`
/// on `HEREDOC`; `body` mirrors `m.group("body")`.
struct Heredoc {
    start: usize,
    end: usize,
    #[allow(dead_code)] // kept for symmetry with Python's named group; not read after matching
    tag: String,
    body: String,
}

/// Hand-coded replacement for `HEREDOC = re.compile(r"<<-?\s*(['\"]?)(?P<tag>...)\1(?P<body>.*?)^\s*(?P=tag)\s*$", re.S | re.M)`.
///
/// The backreference `\1`/`(?P=tag)` -- the closing line must equal the
/// opening tag -- has no `regex`-crate equivalent, so this scans by hand:
/// find `<<`, optionally `-`, optional leading whitespace, an optional quote
/// character, the tag word, the SAME quote character (if one was opened), then
/// the body up to the first subsequent line that is (optional whitespace) +
/// tag + (optional whitespace) and nothing else.
///
/// On any failure to complete a match starting at a given `<<`, retries from
/// `start + 1` -- exactly what `re.finditer` does when the first token matches
/// but the rest of the pattern fails: it does not skip to the next `<<`
/// wholesale, it tries the very next position (which, since the pattern's
/// first literal is `<<`, can only succeed at another `<<` occurrence -- so
/// jumping straight to the next `find("<<")` from there is equivalent).
fn find_heredocs(cmd: &str) -> Vec<Heredoc> {
    let bytes = cmd.as_bytes();
    let n = bytes.len();
    let mut out = Vec::new();
    let mut search_from = 0usize;
    while let Some(rel) = cmd[search_from..].find("<<") {
        let start = search_from + rel;
        let mut p = start + 2;
        if bytes.get(p) == Some(&b'-') {
            p += 1;
        }
        while p < n && is_ws(bytes[p]) {
            p += 1;
        }
        let quote: Option<u8> = match bytes.get(p) {
            Some(&b'\'') => Some(b'\''),
            Some(&b'"') => Some(b'"'),
            _ => None,
        };
        if quote.is_some() {
            p += 1;
        }
        let tag_start = p;
        if p >= n || !(bytes[p].is_ascii_alphabetic() || bytes[p] == b'_') {
            search_from = start + 1;
            continue;
        }
        p += 1;
        while p < n && (bytes[p].is_ascii_alphanumeric() || bytes[p] == b'_') {
            p += 1;
        }
        let tag = &cmd[tag_start..p];
        if let Some(q) = quote {
            if bytes.get(p) != Some(&q) {
                search_from = start + 1;
                continue;
            }
            p += 1;
        }
        let body_start = p;
        match find_heredoc_close(cmd, body_start, tag) {
            Some((body_end, match_end)) => {
                out.push(Heredoc {
                    start,
                    end: match_end,
                    tag: tag.to_string(),
                    body: cmd[body_start..body_end].to_string(),
                });
                search_from = match_end;
            }
            None => {
                search_from = start + 1;
            }
        }
    }
    out
}

/// Finds the first line at or after `body_start` that is, ignoring leading and
/// trailing ASCII whitespace, exactly `tag`. Returns `(body_end, match_end)`
/// where `body_end` is the position right after the newline preceding that
/// line (so the trailing newline is part of the body, matching `^` anchoring
/// AFTER the newline in Python's `re.M` semantics) and `match_end` is the end
/// of the closing-tag line (right before its own trailing newline, or end of
/// string).
fn find_heredoc_close(cmd: &str, body_start: usize, tag: &str) -> Option<(usize, usize)> {
    let mut pos = body_start;
    loop {
        let nl_rel = cmd[pos..].find('\n')?;
        let line_start = pos + nl_rel + 1;
        let line_end = match cmd[line_start..].find('\n') {
            Some(off) => line_start + off,
            None => cmd.len(),
        };
        let line = &cmd[line_start..line_end];
        let after_ws = line.trim_start_matches(|c: char| c.is_ascii_whitespace() && c != '\n');
        if let Some(rest) = after_ws.strip_prefix(tag) {
            if rest.chars().all(|c| c.is_ascii_whitespace() && c != '\n') {
                return Some((line_start, line_end));
            }
        }
        if line_end >= cmd.len() {
            return None;
        }
        pos = line_end;
    }
}

static INTERPRETER_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"\b(?:python3?|bash|sh|zsh|perl|ruby|node)\b\s*-?\s*(?:<<|$|\s)").unwrap()
});

static SPLIT_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"[;&|]|&&").unwrap());

/// Hand-coded replacement for the `-c` quoted-body extraction (used for both
/// `python3 -c '...'` -- feeding `programs` -- and `bash -c '...'` -- feeding
/// `mask_quoted`'s splice). Python: `(['"])(.*?)\1` after the interpreter and
/// `-c`; the backreference (same quote character closes the body) has no
/// `regex`-crate equivalent.
///
/// `prefix_re` matches everything up to and including the OPENING quote
/// character (captured as the pattern's only group, and guaranteed to be the
/// last byte of the match). This scanner then finds the next occurrence of
/// that exact byte as the closing quote -- the non-greedy `.*?` in the
/// original means the FIRST such occurrence, which `str::find` gives directly.
///
/// Uses `Regex::find_at` in an explicit loop (rather than `find_iter`) so that,
/// on a successful match, the next search resumes at the END of the body
/// (skipping anything inside it that might otherwise look like a nested
/// prefix), and on failure (no closing quote found) resumes at `start + 1` --
/// the same "retry at the next position" semantics as the heredoc scanner.
fn find_dash_c_bodies(text: &str, prefix_re: &Regex) -> Vec<(usize, usize, String)> {
    let mut out = Vec::new();
    let mut search_pos = 0usize;
    while search_pos <= text.len() {
        let m = match prefix_re.find_at(text, search_pos) {
            Some(m) => m,
            None => break,
        };
        let quote_byte = text.as_bytes()[m.end() - 1];
        let body_start = m.end();
        match text[body_start..].find(quote_byte as char) {
            Some(off) => {
                let body_end = body_start + off;
                let match_end = body_end + 1;
                out.push((m.start(), match_end, text[body_start..body_end].to_string()));
                search_pos = match_end;
            }
            None => {
                search_pos = m.start() + 1;
            }
        }
    }
    out
}

static PY_C_PREFIX: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"\b(?:python3?|bash|sh|zsh|perl|ruby|node)\s+-c\s+(['"])"#).unwrap()
});

static SHELL_WRAPPER_PREFIX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"\b(?:bash|sh|zsh)\s+-c\s+(['"])"#).unwrap());

/// Port of `split_context`. Returns `(shell_text, programs)`.
fn split_context(cmd: &str) -> (String, Vec<String>) {
    let mut programs = Vec::new();
    let mut shell_parts: Vec<&str> = Vec::new();
    let mut pos = 0usize;
    for hd in find_heredocs(cmd) {
        let head = &cmd[pos..hd.start];
        shell_parts.push(head);
        let last_segment = SPLIT_RE.split(head).last().unwrap_or("");
        let probe = format!("{} <<", last_segment);
        if INTERPRETER_RE.is_match(&probe) {
            programs.push(hd.body.clone());
        }
        pos = hd.end;
    }
    shell_parts.push(&cmd[pos..]);
    let shell_text = shell_parts.join(" ");

    for (_, _, body) in find_dash_c_bodies(cmd, &PY_C_PREFIX) {
        programs.push(body);
    }
    (shell_text, programs)
}

// --- masking ------------------------------------------------------------------

static QUOTED_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r#"'[^']*'|"[^"]*""#).unwrap());

static BARE_PATH_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(&format!(r"^[\w./~$@{{}}-]+\.(?:{})$", ext_re())).unwrap());

/// Port of `mask_quoted` / `_mask_one`.
fn mask_quoted(text: &str) -> String {
    let inner: Vec<String> = find_dash_c_bodies(text, &SHELL_WRAPPER_PREFIX)
        .into_iter()
        .map(|(_, _, body)| body)
        .collect();

    let masked = QUOTED_RE.replace_all(text, |caps: &Captures| {
        let whole = &caps[0];
        let body = &whole[1..whole.len() - 1];
        if BARE_PATH_RE.is_match(body) {
            format!(" {} ", body)
        } else {
            " ".repeat(whole.chars().count())
        }
    });

    if inner.is_empty() {
        masked.into_owned()
    } else {
        let mut parts = vec![masked.into_owned()];
        parts.extend(inner);
        parts.join(" ; ")
    }
}

// --- write patterns: with extension ------------------------------------------

/// A "shell redirect" hit: mirrors the `lhs`/`path` named groups Python's
/// regex captured, plus the overall match span.
struct RedirectMatch {
    #[allow(dead_code)]
    start: usize,
    #[allow(dead_code)]
    end: usize,
    lhs: String,
    path: String,
}

/// Hand-coded replacement for the "shell redirect" pattern:
/// `(?P<pre>^|[;&|])(?P<lhs>[^;&|>]*?)(?<!\\)>>?\s*(?P<path>...)\b`.
///
/// The negative lookbehind `(?<!\\)` -- the `>` must not be an escaped `\>`,
/// e.g. POSIX `[ $a \> $b ]` -- has no `regex`-crate equivalent.
///
/// Because `lhs`'s character class excludes `;`, `&`, `|` AND `>`, for a given
/// "pre" anchor the position of the first following `>` (if any, before a
/// `;`/`&`/`|`) is unique and forced -- `lhs` cannot backtrack past it, escaped
/// or not. So an escaped `>` is a dead end for that anchor, not merely a retry
/// point: the scanner drops it and moves on to the NEXT anchor candidate,
/// exactly what Python's regex engine does once `lhs`'s expansion options are
/// exhausted.
///
/// `path_re` supplies the path grammar (with or without a required
/// extension) as a `^`-anchored regex run against the text immediately
/// following the redirect and any whitespace.
fn find_redirects(text: &str, path_re: &Regex) -> Vec<RedirectMatch> {
    let bytes = text.as_bytes();
    let n = bytes.len();

    // Candidates in increasing "pre" start-position order. Position 0 always
    // gets BOTH the "^" alternative (zero-width, tried first) and, if
    // text[0] is also one of ';','&','|', the character alternative -- this
    // mirrors alternation backtracking: if "^" leads to failure, Python's
    // engine retries the SAME start position with the other branch of
    // `^|[;&|]`, which is exactly what pushing both candidates (in this
    // order) reproduces.
    let mut candidates: Vec<(usize, usize)> = Vec::with_capacity(n / 2 + 1);
    candidates.push((0, 0));
    for (i, &b) in bytes.iter().enumerate() {
        if b == b';' || b == b'&' || b == b'|' {
            candidates.push((i, i + 1));
        }
    }

    let mut out = Vec::new();
    let mut used_until = 0usize;
    for (full_start, lhs_start) in candidates {
        if full_start < used_until {
            continue;
        }
        let mut j = lhs_start;
        let redir_pos = loop {
            if j >= n {
                break None;
            }
            match bytes[j] {
                b'>' => break Some(j),
                b';' | b'&' | b'|' => break None,
                _ => j += 1,
            }
        };
        let redir_pos = match redir_pos {
            Some(p) => p,
            None => continue,
        };
        if redir_pos > 0 && bytes[redir_pos - 1] == b'\\' {
            continue; // escaped '>' -- dead end for this anchor, per the doc comment above
        }
        let redir_len = if redir_pos + 1 < n && bytes[redir_pos + 1] == b'>' {
            2
        } else {
            1
        };
        let mut k = redir_pos + redir_len;
        while k < n && is_ws(bytes[k]) {
            k += 1;
        }
        let tail = &text[k..];
        if let Some(m) = path_re.find(tail) {
            if m.start() == 0 {
                let full_end = k + m.end();
                out.push(RedirectMatch {
                    start: full_start,
                    end: full_end,
                    lhs: text[lhs_start..redir_pos].to_string(),
                    path: tail[..m.end()].to_string(),
                });
                used_until = full_end;
            }
        }
    }
    out
}

fn with_ext_path_re() -> Regex {
    Regex::new(&format!(r"^[^\s;|&>]+\.(?:{})\b", ext_re())).unwrap()
}

fn noext_path_re() -> Regex {
    Regex::new(r"^[^\s;|&>]+").unwrap()
}

static WITH_EXT_PATH_RE: LazyLock<Regex> = LazyLock::new(with_ext_path_re);
static NOEXT_PATH_RE: LazyLock<Regex> = LazyLock::new(noext_path_re);

static TEE_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(&format!(
        r"\btee\s+(?:-a\s+)?(?P<path>[^\s;|&]+\.(?:{}))\b",
        ext_re()
    ))
    .unwrap()
});

static SED_I_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(&format!(
        r"\bsed\b[^|;\n]*?\s(?:-i\b|--in-place\b)[^|;\n]*?(?P<path>[^\s;|&]+\.(?:{}))\b",
        ext_re()
    ))
    .unwrap()
});

static PERL_I_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(&format!(
        r"\bperl\b[^|;\n]*?\s-\w*i\w*\b[^|;\n]*?(?P<path>[^\s;|&]+\.(?:{}))\b",
        ext_re()
    ))
    .unwrap()
});

static TEE_NOEXT_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\btee\s+(?:-a\s+)?(?P<path>[^\s;|&]+)").unwrap());

static SED_I_NOEXT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"\bsed\b[^|;\n]*?\s(?:-i\b|--in-place\b)[^|;\n]*?(?P<path>[^\s;|&]+)").unwrap()
});

static PERL_I_NOEXT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"\bperl\b[^|;\n]*?\s-\w*i\w*\b[^|;\n]*?(?P<path>[^\s;|&]+)").unwrap()
});

static PATH_WRITE_TEXT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(&format!(
        r#"Path\s*\(\s*['"](?P<path>[^'"]+\.(?:{}))['"]\s*\)\s*\.\s*write_text"#,
        ext_re()
    ))
    .unwrap()
});

static OPEN_W_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(&format!(
        r#"open\s*\(\s*['"](?P<path>[^'"]+\.(?:{}))['"]\s*,\s*['"][wa][btx+]*['"]"#,
        ext_re()
    ))
    .unwrap()
});

static P_VAR_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(&format!(
        r#"(?P<var>\w+)\s*=\s*Path\s*\(\s*['"](?P<path>[^'"]+\.(?:{}))['"]\s*\)"#,
        ext_re()
    ))
    .unwrap()
});

static PATH_WRITE_TEXT_NOEXT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"Path\s*\(\s*['"](?P<path>[^'"]+)['"]\s*\)\s*\.\s*write_text"#).unwrap()
});

static OPEN_W_NOEXT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"open\s*\(\s*['"](?P<path>[^'"]+)['"]\s*,\s*['"][wa][btx+]*['"]"#).unwrap()
});

// --- path resolution ----------------------------------------------------------

fn strip_quotes(p: &str) -> String {
    p.trim()
        .trim_matches(|c: char| c == '\'' || c == '"')
        .to_string()
}

static ASSIGN_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?:^|[;&\s])([A-Za-z_]\w*)=([^\s;&|]+)").unwrap());

static VARREF_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\$\{?([A-Za-z_]\w*)\}?").unwrap());

/// Port of `expand_vars`.
fn expand_vars(path: &str, cmd: &str) -> String {
    let mut assigns: HashMap<String, String> = HashMap::new();
    for cap in ASSIGN_RE.captures_iter(cmd) {
        assigns.insert(cap[1].to_string(), cap[2].to_string());
    }
    let mut path = path.to_string();
    for _ in 0..3 {
        let (name, m_start, m_end) = match VARREF_RE.captures(&path) {
            Some(caps) => {
                let m = caps.get(0).unwrap();
                (caps[1].to_string(), m.start(), m.end())
            }
            None => break,
        };
        let val = match assigns.get(&name) {
            Some(v) => v.clone(),
            None => break,
        };
        path = format!("{}{}{}", &path[..m_start], strip_quotes(&val), &path[m_end..]);
    }
    path
}

static UNRESOLVED_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\$\(|`|\$\{?\w").unwrap());

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

fn join_path(base: &str, p: &str) -> String {
    if p.starts_with('/') {
        return p.to_string();
    }
    if base.ends_with('/') {
        format!("{}{}", base, p)
    } else {
        format!("{}/{}", base, p)
    }
}

/// Port of POSIX `os.path.normpath` (from CPython's `posixpath.normpath`),
/// including the historical two-leading-slash special case: `//foo` keeps
/// both slashes, `///foo` collapses to `/foo`.
fn normpath(path: &str) -> String {
    if path.is_empty() {
        return ".".to_string();
    }
    let starts_slash = path.starts_with('/');
    let initial_slashes: usize = if starts_slash {
        if path.starts_with("//") && !path.starts_with("///") {
            2
        } else {
            1
        }
    } else {
        0
    };
    let comps: Vec<&str> = path.split('/').collect();
    let mut new_comps: Vec<&str> = Vec::new();
    for comp in comps {
        if comp.is_empty() || comp == "." {
            continue;
        }
        let keep = comp != ".."
            || (initial_slashes == 0 && new_comps.is_empty())
            || (!new_comps.is_empty() && *new_comps.last().unwrap() == "..");
        if keep {
            new_comps.push(comp);
        } else if !new_comps.is_empty() {
            new_comps.pop();
        }
        // else: ".." at the root of an absolute path with nothing to pop -- dropped silently
    }
    let mut result = new_comps.join("/");
    if initial_slashes > 0 {
        result = "/".repeat(initial_slashes) + &result;
    }
    if result.is_empty() {
        ".".to_string()
    } else {
        result
    }
}

/// Port of `resolve`. `None` means allow (unresolvable target).
fn resolve(path: &str, cmd: &str, base: &str) -> Option<String> {
    let p = expand_vars(&strip_quotes(path), cmd);
    if UNRESOLVED_RE.is_match(&p) {
        return None;
    }
    let p = expanduser(&p);
    let p = if p.starts_with('/') { p } else { join_path(base, &p) };
    Some(normpath(&p))
}

/// Port of `effective_cwd`. `proc_cwd` replaces Python's `os.getcwd()` --
/// the one place this guard reads the process working directory.
fn effective_cwd(shell_text: &str, cmd: &str, proc_cwd: &str) -> String {
    static CD_RE: LazyLock<Regex> =
        LazyLock::new(|| Regex::new(r"(?:^|[;&\n]|&&)\s*cd\s+(?P<dir>[^\s;|&]+)").unwrap());

    let mut last: Option<String> = None;
    for cap in CD_RE.captures_iter(shell_text) {
        last = Some(cap["dir"].to_string());
    }
    let last = match last {
        Some(l) => l,
        None => return proc_cwd.to_string(),
    };
    let d = expand_vars(&strip_quotes(&last), cmd);
    if UNRESOLVED_RE.is_match(&d) {
        return proc_cwd.to_string();
    }
    let d = expanduser(&d);
    if d.starts_with('/') {
        d
    } else {
        join_path(proc_cwd, &d)
    }
}

/// True when the target sits inside a git work tree. Keeps the subprocess
/// call deliberately -- see the module doc comment.
fn in_git_tree(path: &str) -> bool {
    fn dirname(p: &str) -> String {
        match p.rfind('/') {
            Some(0) => "/".to_string(),
            Some(i) => p[..i].to_string(),
            None => String::new(),
        }
    }

    let mut d = dirname(path);
    if d.is_empty() {
        d = "/".to_string();
    }
    while !std::path::Path::new(&d).is_dir() && d != "/" {
        let nd = dirname(&d);
        d = if nd.is_empty() { "/".to_string() } else { nd };
    }

    match std::process::Command::new("git")
        .args(["-C", &d, "rev-parse", "--is-inside-work-tree"])
        .output()
    {
        Ok(out) => out.status.success() && String::from_utf8_lossy(&out.stdout).trim() == "true",
        Err(_) => false, // fail open
    }
}

fn lhs_is_generator(lhs: &str) -> bool {
    let toks: Vec<&str> = lhs
        .trim()
        .split_whitespace()
        .filter(|t| !t.contains('='))
        .collect();
    if toks.is_empty() {
        return false;
    }
    fn basename(s: &str) -> &str {
        s.rsplit('/').next().unwrap_or(s)
    }
    let mut first = basename(toks[0]);
    if matches!(first, "sudo" | "timeout" | "env" | "nice") && toks.len() > 1 {
        first = basename(toks[1]);
    }
    GENERATOR.contains(&first)
}

fn is_script(path: &str) -> bool {
    let base = path.rsplit('/').next().unwrap_or(path);
    if base.contains('.') {
        return false;
    }
    let p = std::path::Path::new(path);
    match std::fs::metadata(p) {
        Ok(m) if m.is_file() => {}
        _ => return false,
    }
    use std::io::Read;
    match std::fs::File::open(p) {
        Ok(mut f) => {
            let mut buf = [0u8; 2];
            match f.read(&mut buf) {
                Ok(2) => &buf == b"#!",
                _ => false,
            }
        }
        Err(_) => false,
    }
}

// --- find_write ---------------------------------------------------------------

/// Return `(rule, resolved_path)` for a write this guard should refuse.
///
/// Order matters: within each pass, rules are tried in the order below, and
/// within a rule, matches are tried left-to-right; the first candidate that
/// resolves, is not exempt, and sits inside a git work tree short-circuits the
/// whole function. This mirrors the Python nesting (`for name, pat in RULES:
/// for m in pat.finditer(...)`) exactly, including which rule "wins" when more
/// than one could fire on the same command.
pub fn find_write(command: &str, cwd: &str) -> (Option<String>, Option<String>) {
    if REMOTE_RE.is_match(command) {
        return (None, None);
    }

    // CONTRACT: `cwd` must be a directory that exists. It stands in for the
    // process's actual working directory, which by construction always does --
    // a real process cannot be chdir'd somewhere that is not there.
    //
    // Normalising a missing `cwd` here would be harness compensation living in
    // the shipped decision function: the only caller that can hand this a
    // nonexistent directory is the differential runner replaying a recorded
    // transcript `cwd` whose worktree has since been deleted. That fallback
    // belongs in the runner, beside the Python harness's matching one in
    // `verdict_python`, so that both sides apply it in the same layer and this
    // function keeps one contract instead of two.
    let proc_cwd: &str = cwd;

    let (shell_text_raw, programs) = split_context(command);
    let base = effective_cwd(&shell_text_raw, command, proc_cwd);
    let shell_text = mask_quoted(&shell_text_raw);

    // Pass 1: SHELL_WRITES over shell_text.
    for rm in find_redirects(&shell_text, &WITH_EXT_PATH_RE) {
        if lhs_is_generator(&rm.lhs) {
            continue;
        }
        if let Some(p) = resolve(&rm.path, command, &base) {
            if !EXEMPT_PATH_RE.is_match(&p) && in_git_tree(&p) {
                return (Some("shell redirect".to_string()), Some(p));
            }
        }
    }
    for cap in TEE_RE.captures_iter(&shell_text) {
        if let Some(p) = resolve(&cap["path"], command, &base) {
            if !EXEMPT_PATH_RE.is_match(&p) && in_git_tree(&p) {
                return (Some("tee".to_string()), Some(p));
            }
        }
    }
    for cap in SED_I_RE.captures_iter(&shell_text) {
        if let Some(p) = resolve(&cap["path"], command, &base) {
            if !EXEMPT_PATH_RE.is_match(&p) && in_git_tree(&p) {
                return (Some("sed -i".to_string()), Some(p));
            }
        }
    }
    for cap in PERL_I_RE.captures_iter(&shell_text) {
        if let Some(p) = resolve(&cap["path"], command, &base) {
            if !EXEMPT_PATH_RE.is_match(&p) && in_git_tree(&p) {
                return (Some("perl -i".to_string()), Some(p));
            }
        }
    }

    // Pass 2: PY_WRITES over each program body, program-major, rule-minor.
    for body in &programs {
        for cap in PATH_WRITE_TEXT_RE.captures_iter(body) {
            if let Some(p) = resolve(&cap["path"], command, &base) {
                if !EXEMPT_PATH_RE.is_match(&p) && in_git_tree(&p) {
                    return (Some("Path.write_text".to_string()), Some(p));
                }
            }
        }
        for cap in OPEN_W_RE.captures_iter(body) {
            if let Some(p) = resolve(&cap["path"], command, &base) {
                if !EXEMPT_PATH_RE.is_match(&p) && in_git_tree(&p) {
                    return (Some("open(...,'w')".to_string()), Some(p));
                }
            }
        }
        for cap in P_VAR_RE.captures_iter(body) {
            let var = &cap["var"];
            let check_re =
                Regex::new(&format!(r"\b{}\s*\.\s*write_text", regex::escape(var))).unwrap();
            if !check_re.is_match(body) {
                continue;
            }
            if let Some(p) = resolve(&cap["path"], command, &base) {
                if !EXEMPT_PATH_RE.is_match(&p) && in_git_tree(&p) {
                    return (Some("p.write_text".to_string()), Some(p));
                }
            }
        }
    }

    // Pass 3: SHELL_WRITES_NOEXT over shell_text, narrowed by `is_script`.
    for rm in find_redirects(&shell_text, &NOEXT_PATH_RE) {
        if lhs_is_generator(&rm.lhs) {
            continue;
        }
        if let Some(p) = resolve(&rm.path, command, &base) {
            if is_script(&p) && !EXEMPT_PATH_RE.is_match(&p) && in_git_tree(&p) {
                return (
                    Some("shell redirect (extensionless script)".to_string()),
                    Some(p),
                );
            }
        }
    }
    for cap in TEE_NOEXT_RE.captures_iter(&shell_text) {
        if let Some(p) = resolve(&cap["path"], command, &base) {
            if is_script(&p) && !EXEMPT_PATH_RE.is_match(&p) && in_git_tree(&p) {
                return (Some("tee (extensionless script)".to_string()), Some(p));
            }
        }
    }
    for cap in SED_I_NOEXT_RE.captures_iter(&shell_text) {
        if let Some(p) = resolve(&cap["path"], command, &base) {
            if is_script(&p) && !EXEMPT_PATH_RE.is_match(&p) && in_git_tree(&p) {
                return (Some("sed -i (extensionless script)".to_string()), Some(p));
            }
        }
    }
    for cap in PERL_I_NOEXT_RE.captures_iter(&shell_text) {
        if let Some(p) = resolve(&cap["path"], command, &base) {
            if is_script(&p) && !EXEMPT_PATH_RE.is_match(&p) && in_git_tree(&p) {
                return (Some("perl -i (extensionless script)".to_string()), Some(p));
            }
        }
    }

    // Pass 4: PY_WRITES_NOEXT over each program body.
    for body in &programs {
        for cap in PATH_WRITE_TEXT_NOEXT_RE.captures_iter(body) {
            if let Some(p) = resolve(&cap["path"], command, &base) {
                if is_script(&p) && !EXEMPT_PATH_RE.is_match(&p) && in_git_tree(&p) {
                    return (
                        Some("Path.write_text (extensionless script)".to_string()),
                        Some(p),
                    );
                }
            }
        }
        for cap in OPEN_W_NOEXT_RE.captures_iter(body) {
            if let Some(p) = resolve(&cap["path"], command, &base) {
                if is_script(&p) && !EXEMPT_PATH_RE.is_match(&p) && in_git_tree(&p) {
                    return (
                        Some("open(...,'w') (extensionless script)".to_string()),
                        Some(p),
                    );
                }
            }
        }
    }

    (None, None)
}

// --- unit tests for the four hand-coded scanners -----------------------------

#[cfg(test)]
mod tests {
    use super::*;

    // --- 1. heredoc tag matching (replaces `(?P<tag>...)\1 ... (?P=tag)`) ---

    #[test]
    fn heredoc_unquoted_tag_matches() {
        let cmd = "cat > notes.md <<EOF\nhello\nEOF";
        let hds = find_heredocs(cmd);
        assert_eq!(hds.len(), 1);
        assert_eq!(hds[0].tag, "EOF");
        // Body starts right after the opening tag -- BEFORE that line's own
        // trailing newline -- so it includes a leading '\n', matching
        // Python's `(?P<body>.*?)` starting point exactly.
        assert_eq!(hds[0].body, "\nhello\n");
    }

    #[test]
    fn heredoc_quoted_tag_matches_and_requires_same_quote() {
        let cmd = "python3 - <<'PY'\nprint(1)\nPY";
        let hds = find_heredocs(cmd);
        assert_eq!(hds.len(), 1);
        assert_eq!(hds[0].tag, "PY");
        assert_eq!(hds[0].body, "\nprint(1)\n");
    }

    #[test]
    fn heredoc_indented_closing_tag_matches() {
        let cmd = "cat <<-EOF\nbody\n  EOF";
        let hds = find_heredocs(cmd);
        assert_eq!(hds.len(), 1);
        assert_eq!(hds[0].tag, "EOF");
    }

    #[test]
    fn heredoc_missing_closing_tag_yields_no_match() {
        let cmd = "cat > notes.md <<EOF\nhello\nno closing tag here";
        let hds = find_heredocs(cmd);
        assert!(hds.is_empty());
    }

    #[test]
    fn heredoc_wrong_quote_char_fails_to_open() {
        // opening quote is ', but immediately after the tag there is a "
        // instead of the matching ' -- the whole heredoc attempt must fail,
        // exactly as Python's \1 backreference would refuse to match.
        let cmd = "cat <<'EOF\"\nbody\nEOF";
        let hds = find_heredocs(cmd);
        assert!(hds.is_empty());
    }

    #[test]
    fn heredoc_feeding_interpreter_is_a_program() {
        let cmd = "python3 - <<EOF\nopen('x.py','w').write('y')\nEOF";
        let (shell_text, programs) = split_context(cmd);
        assert_eq!(programs.len(), 1);
        assert!(programs[0].contains("open("));
        // the heredoc body must NOT remain in the shell text
        assert!(!shell_text.contains("write"));
    }

    #[test]
    fn heredoc_feeding_cat_redirect_is_a_document_not_a_program() {
        let cmd = "cat > notes.md <<EOF\nsed -i s/a/b/ fake.py\nEOF";
        let (_shell_text, programs) = split_context(cmd);
        assert!(programs.is_empty());
    }

    // --- 2 & 3. `-c '...'` quoted body extraction (replaces `(['\"])(.*?)\1`) ---

    #[test]
    fn dash_c_single_quoted_body() {
        let text = "python3 -c 'open(\"x.py\",\"w\")'";
        let got = find_dash_c_bodies(text, &PY_C_PREFIX);
        assert_eq!(got.len(), 1);
        assert_eq!(got[0].2, "open(\"x.py\",\"w\")");
    }

    #[test]
    fn dash_c_double_quoted_body() {
        let text = "bash -c \"sed -i 's/a/b/' notes.md\"";
        let got = find_dash_c_bodies(text, &SHELL_WRAPPER_PREFIX);
        assert_eq!(got.len(), 1);
        assert_eq!(got[0].2, "sed -i 's/a/b/' notes.md");
    }

    #[test]
    fn dash_c_closing_quote_must_match_opening_quote_char() {
        // opens with ' but the first quote character encountered after that
        // is " -- must not be treated as the close; body runs until the next '.
        let text = "python3 -c 'print(\"hi\")'";
        let got = find_dash_c_bodies(text, &PY_C_PREFIX);
        assert_eq!(got.len(), 1);
        assert_eq!(got[0].2, "print(\"hi\")");
    }

    #[test]
    fn dash_c_unterminated_quote_yields_no_body() {
        let text = "python3 -c 'open(\"x.py\",\"w\")";
        let got = find_dash_c_bodies(text, &PY_C_PREFIX);
        assert!(got.is_empty());
    }

    // --- 4. escaped-redirect case (replaces `(?<!\\)>>?`) ---

    #[test]
    fn plain_redirect_is_a_write() {
        let hits = find_redirects("echo x > out.py", &WITH_EXT_PATH_RE);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].path, "out.py");
    }

    #[test]
    fn escaped_redirect_is_not_a_write() {
        // POSIX string-comparison test, `\>` is escaped and must not be read
        // as a redirect at all.
        let hits = find_redirects("[ $a \\> $b ]", &WITH_EXT_PATH_RE);
        assert!(hits.is_empty());
    }

    #[test]
    fn escaped_redirect_does_not_hide_a_later_real_redirect() {
        let hits = find_redirects("[ $a \\> $b ]; echo x > out.py", &WITH_EXT_PATH_RE);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].path, "out.py");
    }

    #[test]
    fn double_redirect_append_is_a_write() {
        let hits = find_redirects("echo x >> out.py", &WITH_EXT_PATH_RE);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].path, "out.py");
    }

    // --- a couple of end-to-end sanity checks on find_write itself ---

    #[test]
    fn generator_lhs_is_exempt_from_redirect_rule() {
        let (rule, _path) = find_write("git log --oneline > CHANGELOG.md", "/tmp");
        assert_eq!(rule, None);
    }

    #[test]
    fn remote_command_is_never_flagged() {
        let (rule, path) = find_write("ssh host \"sed -i s/a/b/ notes.md\"", "/tmp");
        assert_eq!(rule, None);
        assert_eq!(path, None);
    }
}
