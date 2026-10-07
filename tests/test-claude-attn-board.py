#!/usr/bin/env python3
"""Tests for `claude-attn-board`.

Run: python3 tests/test-claude-attn-board.py -v

The board is split into a pure CORE (parsing, grouping, folding, the row
model, cursor/scroll math, click mapping -- tested here directly, no
terminal needed) and a thin curses/IO SHELL (not unit-tested; exercised
only by the ATTN_ONCE end-to-end test, which runs the real script as a
subprocess with HOME pointed at a temp dir and ATTN_SOCKETS="" so it
never opens a real tmux server, per the house rule for this suite).

Session/project names used in fixtures are neutral placeholders
(`alpha_c`, `beta_code`, `/home/u/proj`, ...) -- never real hostnames or
project names, per the house rule for this public repo.
"""
import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from importlib.machinery import SourceFileLoader

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "bin", "claude-attn-board")

_loader = SourceFileLoader("claude_attn_board", SCRIPT)
_spec = importlib.util.spec_from_loader("claude_attn_board", _loader)
board = importlib.util.module_from_spec(_spec)
_loader.exec_module(board)


def make_line(ts, status="waiting", sess_win="alpha_c:0", wname="shell",
              sockname="inner", cpath="/home/u/proj", label="",
              outer=""):
    fields = [str(ts), status, sess_win, wname, sockname, cpath, label,
              outer]
    return "\t".join(fields) + "\n"


# ---------------------------------------------------------------------
# 1. parse_state_entry
# ---------------------------------------------------------------------
class ParseStateEntryTests(unittest.TestCase):
    def test_8_fields_parses_all(self):
        line = make_line(1000, status="done", sess_win="alpha_c:3",
                          wname="win", sockname="inner-2", cpath="/a/b",
                          label="my label", outer="main:1")
        e = board.parse_state_entry("k1", line)
        self.assertEqual(e.ts, 1000)
        self.assertEqual(e.status, "done")
        self.assertEqual(e.sess_win, "alpha_c:3")
        self.assertEqual(e.wname, "win")
        self.assertEqual(e.sockname, "inner-2")
        self.assertEqual(e.cpath, "/a/b")
        self.assertEqual(e.label, "my label")
        self.assertEqual(e.outer, "main:1")

    def test_7_fields_outer_defaults_empty(self):
        old = "1000\twaiting\talpha_c:0\tshell\tinner\t/a/b\tlbl\n"
        e = board.parse_state_entry("k1", old)
        self.assertIsNotNone(e)
        self.assertEqual(e.outer, "")

    def test_empty_ts_skipped(self):
        line = "\twaiting\talpha_c:0\tshell\tinner\t/a/b\tlbl\t\n"
        self.assertIsNone(board.parse_state_entry("k1", line))

    def test_garbage_ts_skipped(self):
        line = "not-a-ts\twaiting\talpha_c:0\tshell\tinner\t/a/b\tlbl\t\n"
        self.assertIsNone(board.parse_state_entry("k1", line))

    def test_label_empty_falls_back_to_wname_at_render(self):
        line = make_line(1000, wname="win-name", label="")
        e = board.parse_state_entry("k1", line)
        self.assertEqual(e.label, "")
        self.assertEqual(e.wname, "win-name")
        # the fallback itself happens at render time:
        cls = {"kind": "read", "age": 5}
        segs = board.render_entry_segs(e, cls, False, 20, 20)
        self.assertIn("win-name", board.plain_text(segs))


# ---------------------------------------------------------------------
# 2. session/window split + socket resolution
# ---------------------------------------------------------------------
class SplitSessionWindowTests(unittest.TestCase):
    def test_splits_on_last_colon(self):
        self.assertEqual(board.split_session_window("a.b:c:3"),
                          ("a.b:c", "3"))

    def test_no_colon_is_none(self):
        self.assertIsNone(board.split_session_window("nocolon"))


class ResolveSocketTests(unittest.TestCase):
    def test_matches_by_basename(self):
        sockets = ["/tmp/tmux-1000-inner", "/tmp/tmux-1000-inner-2"]
        self.assertEqual(board.resolve_socket("tmux-1000-inner-2", sockets),
                          "/tmp/tmux-1000-inner-2")

    def test_no_match_is_none(self):
        sockets = ["/tmp/tmux-1000-inner"]
        self.assertIsNone(board.resolve_socket("nope", sockets))


# ---------------------------------------------------------------------
# 3. fmt_age boundaries
# ---------------------------------------------------------------------
class FmtAgeTests(unittest.TestCase):
    def test_boundaries(self):
        self.assertEqual(board.fmt_age(59), "59s")
        self.assertEqual(board.fmt_age(60), "1m")
        self.assertEqual(board.fmt_age(3599), "59m")
        self.assertEqual(board.fmt_age(3600), "1h")
        self.assertEqual(board.fmt_age(86399), "23h")
        self.assertEqual(board.fmt_age(86400), "1d")


# ---------------------------------------------------------------------
# 4. clip() by display width
# ---------------------------------------------------------------------
class ClipTests(unittest.TestCase):
    def test_cjk_counts_as_2_cols(self):
        self.assertEqual(board.disp_width("中文"), 4)

    def test_clip_adds_ellipsis(self):
        self.assertEqual(board.clip("abcdef", 4), "abc…")

    def test_clip_cjk_never_splits_wide_char(self):
        # "中文標題" is 4 chars * 2 cols = 8 cols; clipping to 5 cols must
        # not emit a half character.
        out = board.clip("中文標題", 5)
        self.assertLessEqual(board.disp_width(out), 5)
        for ch in out:
            self.assertIn(ch, "中文標題…")

    def test_n_lt_1_is_empty(self):
        self.assertEqual(board.clip("abc", 0), "")
        self.assertEqual(board.clip("abc", -1), "")


# ---------------------------------------------------------------------
# 5. classify
# ---------------------------------------------------------------------
class ClassifyTests(unittest.TestCase):
    def mk(self, status="waiting", ts=1000):
        return board.Entry("k1", ts, status, "alpha_c:0", "w", "inner",
                            "/a/b", "", "")

    def test_running(self):
        cls = board.classify_entry(self.mk("running"), 1010, 0, 300)
        self.assertEqual(cls["kind"], "running")

    def test_unread_when_viewed_before_event(self):
        cls = board.classify_entry(self.mk(), 1010, 500, 300)
        self.assertEqual(cls["kind"], "unread")

    def test_read_when_viewed_after_event(self):
        cls = board.classify_entry(self.mk(), 1010, 2000, 300)
        self.assertEqual(cls["kind"], "read")

    def test_alert_dot_past_age_alert(self):
        cls = board.classify_entry(self.mk(ts=1000), 1000 + 301, 0, 300)
        self.assertTrue(cls["alert"])
        cls2 = board.classify_entry(self.mk(ts=1000), 1000 + 299, 0, 300)
        self.assertFalse(cls2["alert"])


# ---------------------------------------------------------------------
# 6. grouping
# ---------------------------------------------------------------------
class BuildGroupsTests(unittest.TestCase):
    def test_groups_ordered_by_newest_entries_ts_desc(self):
        entries = [
            board.Entry("k1", 100, "waiting", "a:0", "w", "inner",
                        "/proj/a", "", ""),
            board.Entry("k2", 300, "waiting", "a:1", "w", "inner",
                        "/proj/b", "", ""),
            board.Entry("k3", 200, "waiting", "a:2", "w", "inner",
                        "/proj/a", "", ""),
        ]
        groups = board.build_groups(entries, 1000, {}, 300)
        self.assertEqual([g["cpath"] for g in groups], ["/proj/b", "/proj/a"])
        a_group = groups[1]
        self.assertEqual([e.key for e, _ in a_group["entries"]], ["k3", "k1"])


# ---------------------------------------------------------------------
# 7. fold: auto, show-all override, manual override expiry
# ---------------------------------------------------------------------
class FoldTests(unittest.TestCase):
    def mk_group(self, unread=0, run=0, read=0, newest=1000,
                 cpath="/proj/a"):
        return {"cpath": cpath, "newest": newest, "entries": [],
                "unread": unread, "read": read, "run": run}

    def test_auto_fold_no_unread_no_running(self):
        g = self.mk_group(unread=0, run=0, read=3)
        self.assertTrue(board.auto_fold(g))

    def test_auto_unfold_when_unread_or_running(self):
        self.assertFalse(board.auto_fold(self.mk_group(unread=1)))
        self.assertFalse(board.auto_fold(self.mk_group(run=1)))

    def test_show_all_overrides_auto_fold(self):
        g = self.mk_group(unread=0, run=0)
        self.assertTrue(board.resolve_fold(g, False, {}))
        self.assertFalse(board.resolve_fold(g, True, {}))

    def test_manual_override_sticks_until_newer_event(self):
        g = self.mk_group(unread=0, run=0, newest=1000)
        fold_ovr = {}
        folded = board.resolve_fold(g, False, fold_ovr)
        self.assertTrue(folded)  # auto-folded
        board.toggle_group_fold(g, folded, fold_ovr)
        # same newest ts -> override sticks (now open)
        self.assertFalse(board.resolve_fold(g, False, fold_ovr))
        self.assertIn(g["cpath"], fold_ovr)

    def test_manual_override_expires_on_newer_event(self):
        g = self.mk_group(unread=0, run=0, newest=1000)
        fold_ovr = {}
        folded = board.resolve_fold(g, False, fold_ovr)
        board.toggle_group_fold(g, folded, fold_ovr)
        self.assertFalse(board.resolve_fold(g, False, fold_ovr))
        # a newer event lands in the group
        g["newest"] = 1001
        self.assertTrue(board.resolve_fold(g, False, fold_ovr))
        self.assertNotIn(g["cpath"], fold_ovr)


# ---------------------------------------------------------------------
# 8. visible-row model: folded group shows only its header
# ---------------------------------------------------------------------
class BuildRowsTests(unittest.TestCase):
    def test_folded_group_hides_entries(self):
        e = board.Entry("k1", 100, "waiting", "a:0", "w", "inner",
                         "/proj/a", "", "")
        groups = [{"cpath": "/proj/a", "newest": 100,
                   "entries": [(e, {"kind": "read", "age": 5})],
                   "unread": 0, "read": 1, "run": 0}]
        rows = board.build_rows(groups, False, {})
        self.assertEqual([r["kind"] for r in rows], ["header"])

    def test_unfolded_group_shows_entries(self):
        e = board.Entry("k1", 100, "waiting", "a:0", "w", "inner",
                         "/proj/a", "", "")
        groups = [{"cpath": "/proj/a", "newest": 100,
                   "entries": [(e, {"kind": "unread", "age": 5,
                                    "alert": False})],
                   "unread": 1, "read": 0, "run": 0}]
        rows = board.build_rows(groups, False, {})
        self.assertEqual([r["kind"] for r in rows], ["header", "entry"])


# ---------------------------------------------------------------------
# 9. cursor movement + survival across refresh
# ---------------------------------------------------------------------
def mk_rows(n_groups=2, entries_per_group=2):
    groups = []
    rows = []
    for gi in range(n_groups):
        cpath = "/proj/%d" % gi
        rows.append({"kind": "header", "cpath": cpath, "key": None})
        for ei in range(entries_per_group):
            rows.append({"kind": "entry", "cpath": cpath,
                         "key": "k-%d-%d" % (gi, ei)})
    return rows


class CursorTests(unittest.TestCase):
    def test_jk_gG_clamp(self):
        rows = mk_rows()
        n = len(rows)
        idx, _ = board.handle_key("j", rows, n - 1)
        self.assertEqual(idx, n - 1)  # clamp at bottom
        idx, _ = board.handle_key("k", rows, 0)
        self.assertEqual(idx, 0)  # clamp at top
        idx, _ = board.handle_key("G", rows, 0)
        self.assertEqual(idx, n - 1)
        idx, _ = board.handle_key("g", rows, n - 1)
        self.assertEqual(idx, 0)

    def test_cursor_survives_refresh_on_same_entry(self):
        rows = mk_rows()
        last = ("entry", "k-0-1")
        idx = board.locate_cursor(rows, last)
        self.assertEqual(rows[idx]["key"], "k-0-1")

    def test_cursor_falls_back_to_header_when_entry_vanishes(self):
        rows = mk_rows()
        last = ("entry", "gone-key", "/proj/1")
        idx = board.locate_cursor(rows, last)
        self.assertEqual(rows[idx]["kind"], "header")
        self.assertEqual(rows[idx]["cpath"], "/proj/1")


# ---------------------------------------------------------------------
# 10. Enter / space-o actions
# ---------------------------------------------------------------------
class KeyActionTests(unittest.TestCase):
    def test_enter_on_header_toggles(self):
        rows = mk_rows()
        idx, action = board.handle_key("ENTER", rows, 0)
        self.assertEqual(action, {"type": "toggle", "cpath": "/proj/0"})

    def test_enter_on_entry_jumps(self):
        rows = mk_rows()
        idx, action = board.handle_key("ENTER", rows, 1)
        self.assertEqual(action["type"], "jump")
        self.assertEqual(action["key"], "k-0-0")

    def test_space_and_o_toggle_cursor_row_group(self):
        rows = mk_rows()
        _, a1 = board.handle_key(" ", rows, 2)  # an entry row
        _, a2 = board.handle_key("o", rows, 2)
        self.assertEqual(a1, {"type": "toggle", "cpath": "/proj/0"})
        self.assertEqual(a2, {"type": "toggle", "cpath": "/proj/0"})


# ---------------------------------------------------------------------
# 11. click mapping
# ---------------------------------------------------------------------
class ClickTests(unittest.TestCase):
    def test_click_entry_jumps(self):
        row_actions = [("header", "/a", None), ("entry", "/a", "k1"), None]
        self.assertEqual(board.handle_click(1, row_actions),
                          {"type": "jump", "cpath": "/a", "key": "k1"})

    def test_click_header_toggles(self):
        row_actions = [("header", "/a", None), ("entry", "/a", "k1")]
        self.assertEqual(board.handle_click(0, row_actions),
                          {"type": "toggle", "cpath": "/a"})

    def test_click_outside_does_nothing(self):
        row_actions = [("header", "/a", None)]
        self.assertIsNone(board.handle_click(5, row_actions))
        self.assertIsNone(board.handle_click(-1, row_actions))


# ---------------------------------------------------------------------
# 12. jump failure never raises
# ---------------------------------------------------------------------
class RunJumpTests(unittest.TestCase):
    def test_nonzero_exit_reported_not_raised(self):
        class FakeResult:
            returncode = 3
        calls = []

        def fake_run(argv):
            calls.append(argv)
            return FakeResult()

        rc = board.run_jump("/bin/fake-jump", "/tmp/sock", "sess", "2",
                             run_fn=fake_run)
        self.assertEqual(rc, 3)
        self.assertEqual(calls, [["/bin/fake-jump", "/tmp/sock", "sess", "2"]])

    def test_exec_error_does_not_raise(self):
        def boom(argv):
            raise OSError("no such file")
        rc = board.run_jump("/bin/missing", "/tmp/sock", "sess", "2",
                             run_fn=boom)
        self.assertEqual(rc, 1)

    def test_jump_target_uses_rsplit_and_basename(self):
        sockets = ["/tmp/tmux-1000-inner", "/tmp/tmux-1000-inner-2"]
        e = board.Entry("k1", 1, "waiting", "a.b:c:3", "w",
                         "tmux-1000-inner-2", "/a", "", "")
        target = board.jump_target_for_entry(e, sockets)
        self.assertEqual(target, ("/tmp/tmux-1000-inner-2", "a.b:c", "3"))


# ---------------------------------------------------------------------
# 13. cleanup_stale
# ---------------------------------------------------------------------
class CleanupStaleTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="attn-board-test-")
        self.state_dir = os.path.join(self.tmp, "tmux-status")
        self.viewed_dir = os.path.join(self.state_dir, ".viewed")
        os.makedirs(self.viewed_dir)
        os.makedirs(os.path.join(self.state_dir, "ctx"))  # subdir to skip

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def write(self, name, ts, text_extra=""):
        with open(os.path.join(self.state_dir, name), "w") as f:
            f.write(make_line(ts) if not text_extra else text_extra)

    def test_skips_subdirectories(self):
        board.cleanup_stale(self.state_dir, self.viewed_dir, set(), 1000, 0,
                             40)
        self.assertTrue(os.path.isdir(os.path.join(self.state_dir, "ctx")))

    def test_removes_entry_for_gone_window(self):
        self.write("k-alive", 100)
        self.write("k-dead", 100)
        board.cleanup_stale(self.state_dir, self.viewed_dir, {"k-alive"},
                             1000, 0, 40)
        self.assertTrue(os.path.exists(os.path.join(self.state_dir,
                                                       "k-alive")))
        self.assertFalse(os.path.exists(os.path.join(self.state_dir,
                                                        "k-dead")))

    def test_max_age_expiry(self):
        self.write("k-old", 100)
        self.write("k-new", 990)
        board.cleanup_stale(self.state_dir, self.viewed_dir,
                             {"k-old", "k-new"}, 1000, 500, 40)
        self.assertFalse(os.path.exists(os.path.join(self.state_dir,
                                                        "k-old")))
        self.assertTrue(os.path.exists(os.path.join(self.state_dir,
                                                       "k-new")))

    def test_cap_evicts_oldest(self):
        keys = set()
        for i in range(5):
            name = "k-%d" % i
            self.write(name, 100 + i)
            keys.add(name)
        board.cleanup_stale(self.state_dir, self.viewed_dir, keys, 1000, 0, 3)
        remaining = sorted(os.listdir(self.state_dir))
        remaining = [r for r in remaining if not r.startswith(".") and
                     r != "ctx"]
        self.assertEqual(sorted(remaining), ["k-2", "k-3", "k-4"])

    def test_prunes_orphan_viewed_stamps(self):
        self.write("k-alive", 100)
        open(os.path.join(self.viewed_dir, "k-alive"), "w").close()
        open(os.path.join(self.viewed_dir, "k-orphan"), "w").close()
        board.cleanup_stale(self.state_dir, self.viewed_dir, {"k-alive"},
                             1000, 0, 40)
        self.assertTrue(os.path.exists(os.path.join(self.viewed_dir,
                                                       "k-alive")))
        self.assertFalse(os.path.exists(os.path.join(self.viewed_dir,
                                                        "k-orphan")))


# ---------------------------------------------------------------------
# 14. bells dedupe
# ---------------------------------------------------------------------
class DedupeBellsTests(unittest.TestCase):
    def test_dedupes_against_existing_claude_entries(self):
        existing = {board.make_key("inner", "alpha_c", "0")}
        bells = [("inner", "alpha_c", "0", "shell"),
                 ("inner", "beta_code", "1", "vim")]
        out = board.dedupe_bells(bells, existing)
        self.assertEqual(out, [("inner", "beta_code", "1", "vim")])


# ---------------------------------------------------------------------
# 15. usage gauge
# ---------------------------------------------------------------------
class UsageGaugeTests(unittest.TestCase):
    def test_absent_cache_is_none(self):
        self.assertIsNone(board.render_usage_segments(None, 80, 1000))

    def test_narrow_width_falls_back_to_compact(self):
        cache = {"upd": 1000, "fp": 63, "fr": "", "wp": 28, "wr": ""}
        plain, _ = board.render_usage_segments(cache, 15, 1000)
        self.assertIn("5h", plain)
        self.assertIn("63%", plain)
        self.assertLessEqual(board.disp_width(plain), 15)


# ---------------------------------------------------------------------
# 16. scroll keeps cursor visible with markers
# ---------------------------------------------------------------------
class ScrollTests(unittest.TestCase):
    def test_follow_cursor_shows_up_marker(self):
        rows = mk_rows(n_groups=10, entries_per_group=0)  # 10 header rows
        total = len(rows)
        avail = 4
        scroll = board.follow_cursor(9, 0, avail, total)
        view, scroll = board.windowed_rows(rows, scroll, avail)
        self.assertEqual(view[0]["kind"], "marker")
        self.assertIn("more", view[0]["text"])

    def test_follow_cursor_shows_down_marker_at_top(self):
        rows = mk_rows(n_groups=10, entries_per_group=0)
        total = len(rows)
        avail = 4
        scroll = board.follow_cursor(0, 0, avail, total)
        view, scroll = board.windowed_rows(rows, scroll, avail)
        self.assertEqual(view[-1]["kind"], "marker")


# ---------------------------------------------------------------------
# 17. ATTN_ONCE end-to-end
# ---------------------------------------------------------------------
class AttnOnceEndToEndTests(unittest.TestCase):
    def test_end_to_end(self):
        tmp = tempfile.mkdtemp(prefix="attn-board-e2e-")
        try:
            state_dir = os.path.join(tmp, ".claude", "tmux-status")
            os.makedirs(state_dir)
            os.makedirs(os.path.join(state_dir, "ctx"))  # must be skipped
            now = int(time.time())
            with open(os.path.join(state_dir, "inner__alpha_c__0"), "w") as f:
                f.write(make_line(now, status="waiting", sess_win="alpha_c:0",
                                   wname="shellw", sockname="inner",
                                   cpath="/home/u/proj-a", label="label-one",
                                   outer=""))
            with open(os.path.join(state_dir, "inner__alpha_c__1"), "w") as f:
                f.write(make_line(now - 10, status="done",
                                   sess_win="alpha_c:1", wname="shellw2",
                                   sockname="inner", cpath="/home/u/proj-b",
                                   label="label-two", outer="main:3"))

            env = dict(os.environ)
            env["HOME"] = tmp
            env["ATTN_ONCE"] = "1"
            env["ATTN_SOCKETS"] = ""  # never touch a real tmux server
            env["COLUMNS"] = "100"
            env["LINES"] = "30"
            result = subprocess.run([sys.executable, SCRIPT], env=env,
                                     capture_output=True, text=True,
                                     timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr)
            out = result.stdout
            self.assertIn("label-one", out)
            self.assertIn("label-two", out)
            self.assertIn("⇐", out)  # outer marker for the 2nd entry
            self.assertIn("main:3", out)
            # no eviction happened
            self.assertTrue(os.path.exists(
                os.path.join(state_dir, "inner__alpha_c__0")))
            self.assertTrue(os.path.exists(
                os.path.join(state_dir, "inner__alpha_c__1")))
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


# ---------------------------------------------------------------------
# 18. meta shows outer only when non-empty
# ---------------------------------------------------------------------
class MetaTests(unittest.TestCase):
    def test_meta_with_outer(self):
        e = board.Entry("k1", 1, "waiting", "alpha_c:0", "w", "inner", "/a",
                         "", "main:2")
        self.assertEqual(board.entry_meta_text(e), "[alpha_c:0 ⇐ main:2]")

    def test_meta_without_outer(self):
        e = board.Entry("k1", 1, "waiting", "alpha_c:0", "w", "inner", "/a",
                         "", "")
        self.assertEqual(board.entry_meta_text(e), "[alpha_c:0]")


# ---------------------------------------------------------------------
# 19. CJK/mixed labels align: the age column starts at the same display
#     column across rows with ASCII, pure-CJK and mixed labels, including
#     a name long enough to need clipping.
# ---------------------------------------------------------------------
class AlignmentTests(unittest.TestCase):
    def render(self, label, namecap=20, metacap=20):
        e = board.Entry("k1", 1, "waiting", "alpha_c:0", "w", "inner", "/a",
                         label, "")
        cls = {"kind": "unread", "age": 5, "alert": False}
        return board.render_entry_segs(e, cls, False, namecap, metacap)

    def prefix_width(self, label, namecap=20, metacap=20):
        """Display width of everything up to and including the (padded)
        name field: indent + dot + icon + sep + name. Fixed across rows
        iff the name field is always padded to exactly `namecap` columns
        regardless of content -- the real behavior under test."""
        segs = self.render(label, namecap, metacap)
        # segs layout: [indent, dot, icon, sep, name, age, meta]
        prefix_segs = segs[:5]
        return board.disp_width("".join(t for t, _ in prefix_segs))

    def test_names_align_across_ascii_cjk_and_mixed(self):
        names = ["abc", "中文標題", "AI 中文 mixed",
                 "中文標題很長很長很長"]
        widths = [self.prefix_width(n) for n in names]
        self.assertEqual(len(set(widths)), 1, "the age column must start "
                          "at the same display column for every row, "
                          "regardless of CJK/mixed name content")

    def test_clipped_cjk_name_never_exceeds_namecap_or_splits_wide_char(self):
        namecap = 6
        long_cjk = "中文標題很長很長"
        clipped = board.clip_pad(long_cjk, namecap)
        self.assertEqual(board.disp_width(clipped), namecap)
        for ch in clipped:
            if ch != " ":
                self.assertIn(ch, long_cjk + "…")

    def test_rendered_row_age_field_at_identical_offset(self):
        # Build full rows (ascii vs CJK name) and check the literal
        # rendered PLAIN text lines up at the same column for the start
        # of the age field (a space-padded 5-char slot, so the first
        # column of that slot need not itself be a digit -- what must
        # be identical is where that slot BEGINS).
        namecap, metacap = 20, 20
        text_ascii = board.plain_text(self.render("abc", namecap, metacap))
        text_cjk = board.plain_text(
            self.render("中文標題", namecap, metacap))
        prefix = self.prefix_width("abc", namecap, metacap)
        self.assertEqual(prefix, self.prefix_width(
            "中文標題", namecap, metacap))

        def col_at(text, col):
            total = 0
            for ch in text:
                if total == col:
                    return ch
                total += board.char_width(ch)
            return None
        # the age slot is " %5s  " -- its very first column is always a
        # single separating space, identical on both rows.
        self.assertEqual(col_at(text_ascii, prefix), " ")
        self.assertEqual(col_at(text_cjk, prefix), " ")
        # and the digit itself (right-justified in the 5-wide slot) lands
        # at the same column on both rows too.
        digit_col = prefix + 1 + 3  # sep(1) + 3 leading spaces before "5s"
        self.assertEqual(col_at(text_ascii, digit_col), "5")
        self.assertEqual(col_at(text_cjk, digit_col), "5")


# ---------------------------------------------------------------------
# 20. mouse-wheel scrolling
# ---------------------------------------------------------------------
class WheelScrollTests(unittest.TestCase):
    def test_wheel_clamps_at_top_and_bottom(self):
        total, avail = 20, 5
        self.assertEqual(board.scroll_wheel(0, -3, total, avail), 0)
        self.assertEqual(board.scroll_wheel(14, 3, total, avail), 15)
        self.assertEqual(board.scroll_wheel(1, -3, total, avail), 0)

    def test_cursor_follows_minimally_into_view(self):
        total, avail = 20, 5
        # cursor at 0, scroll wheel-down to 10 -> cursor must move to the
        # first visible row, not jump to the middle
        new_idx = board.clamp_cursor_to_view(0, 10, avail, total)
        self.assertGreaterEqual(new_idx, 10)
        self.assertLessEqual(new_idx, 14)
        # cursor already inside the view -> untouched
        self.assertEqual(board.clamp_cursor_to_view(11, 10, avail, total), 11)

    def test_click_mapping_after_wheel_scroll_hits_right_row(self):
        rows = mk_rows(n_groups=10, entries_per_group=0)
        total = len(rows)
        avail = 4
        scroll = board.scroll_wheel(0, 3, total, avail)
        view, scroll = board.windowed_rows(rows, scroll, avail)
        row_actions = []
        for r in view:
            if r["kind"] == "marker":
                row_actions.append(None)
            else:
                row_actions.append((r["kind"], r["cpath"], r["key"]))
        # the row right after the top "more" marker is rows[scroll+1]
        target_row = rows[scroll + 1]
        action = board.handle_click(1, row_actions)
        self.assertEqual(action, {"type": "toggle",
                                   "cpath": target_row["cpath"]})


if __name__ == "__main__":
    unittest.main()
