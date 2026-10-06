#!/usr/bin/env python3
"""Tests for `claude-attn-jump`.

Run: python3 tests/test-claude-attn-jump.py -v

`claude-attn-jump` jumps the user's real terminal to a tmux window that
lives on an "inner" tmux server, stepping through the "outer" tmux server
first when the inner server's client is itself running inside an outer
tmux pane (a nested-tmux setup). The pure decision core is `plan()`,
tested here with fake data; the I/O layer (querying tmux, reading
/proc/<pid>/environ) is tested either with an injected fake `run`
callable or, for the cases that only real tmux can settle, against
throwaway tmux servers on sockets under a temp directory.

Session/window names used in fixtures are neutral placeholders
(`alpha_c`, `beta_code`, ...) -- never real hostnames or project names,
per the house rule for this public repo.
"""
import importlib.util
import os
import shutil
import subprocess
import tempfile
import unittest
from importlib.machinery import SourceFileLoader

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "bin", "claude-attn-jump")

_loader = SourceFileLoader("claude_attn_jump", SCRIPT)
_spec = importlib.util.spec_from_loader("claude_attn_jump", _loader)
jump = importlib.util.module_from_spec(_spec)
_loader.exec_module(jump)


def have_tmux():
    return shutil.which("tmux") is not None


class PlanTests(unittest.TestCase):
    """Unit tests for the pure core, plan(), with fake clients/outer_panes."""

    def test_01_one_client_inside_one_outer_pane(self):
        clients = [{"tty": "/dev/pts/9", "outer_socket": "/tmp/outer",
                    "outer_pane": "%3"}]
        outer_panes = {("/tmp/outer", "%3"):
                       {"session_id": "$1", "window": "2", "attached": 1}}
        cmds = jump.plan(("/tmp/inner", "$0", "4"), clients, outer_panes)
        self.assertEqual(cmds, [
            ["tmux", "-S", "/tmp/outer", "switch-client", "-t", "$1"],
            ["tmux", "-S", "/tmp/outer", "select-window", "-t", "$1:2"],
            ["tmux", "-S", "/tmp/outer", "select-pane", "-t", "%3"],
            ["tmux", "-S", "/tmp/inner", "select-window", "-t", "$0:4"],
            ["tmux", "-S", "/tmp/inner", "switch-client", "-c", "/dev/pts/9",
             "-t", "$0"],
        ])

    def test_05_client_not_inside_outer_runs_inner_only(self):
        clients = [{"tty": "/dev/pts/2", "outer_socket": None,
                    "outer_pane": None}]
        cmds = jump.plan(("/tmp/inner", "$0", "3"), clients, {})
        self.assertEqual(cmds, [
            ["tmux", "-S", "/tmp/inner", "select-window", "-t", "$0:3"],
            ["tmux", "-S", "/tmp/inner", "switch-client", "-c", "/dev/pts/2",
             "-t", "$0"],
        ])

    def test_06_two_clients_only_one_inside_outer(self):
        not_inside = {"tty": "/dev/pts/1", "outer_socket": None,
                      "outer_pane": None}
        inside = {"tty": "/dev/pts/2", "outer_socket": "/tmp/outer",
                  "outer_pane": "%5"}
        outer_panes = {("/tmp/outer", "%5"):
                       {"session_id": "$2", "window": "0", "attached": 1}}
        cmds = jump.plan(("/tmp/inner", "$0", "1"),
                          [not_inside, inside], outer_panes)
        # The outer step and the final inner switch-client both name the
        # client that IS inside the outer tmux.
        self.assertEqual(cmds[0], ["tmux", "-S", "/tmp/outer",
                                    "switch-client", "-t", "$2"])
        self.assertEqual(cmds[-1][-3], "/dev/pts/2")

    def test_07_two_clients_both_inside_outer_prefers_attached(self):
        a = {"tty": "/dev/pts/1", "outer_socket": "/tmp/outer",
             "outer_pane": "%1"}
        b = {"tty": "/dev/pts/2", "outer_socket": "/tmp/outer",
             "outer_pane": "%2"}
        outer_panes = {
            ("/tmp/outer", "%1"): {"session_id": "$1", "window": "0",
                                    "attached": 0},
            ("/tmp/outer", "%2"): {"session_id": "$2", "window": "0",
                                    "attached": 3},
        }
        cmds = jump.plan(("/tmp/inner", "$0", "1"), [a, b], outer_panes)
        self.assertEqual(cmds[0], ["tmux", "-S", "/tmp/outer",
                                    "switch-client", "-t", "$2"])
        self.assertEqual(cmds[2], ["tmux", "-S", "/tmp/outer", "select-pane",
                                    "-t", "%2"])

        # tie (equal attached counts) -> first listed wins
        outer_panes[("/tmp/outer", "%2")]["attached"] = 0
        cmds = jump.plan(("/tmp/inner", "$0", "1"), [a, b], outer_panes)
        self.assertEqual(cmds[2], ["tmux", "-S", "/tmp/outer", "select-pane",
                                    "-t", "%1"])

    def test_09_outer_session_id_same_text_as_inner_no_confusion(self):
        # Same session_id text on two different sockets must never mix:
        # each command must carry the socket its id actually belongs to.
        clients = [{"tty": "/dev/pts/4", "outer_socket": "/tmp/outer",
                    "outer_pane": "%9"}]
        outer_panes = {("/tmp/outer", "%9"):
                       {"session_id": "$0", "window": "2", "attached": 1}}
        cmds = jump.plan(("/tmp/inner", "$0", "7"), clients, outer_panes)
        outer_cmds = [c for c in cmds if c[2] == "/tmp/outer"]
        inner_cmds = [c for c in cmds if c[2] == "/tmp/inner"]
        self.assertEqual(len(outer_cmds), 3)
        self.assertEqual(len(inner_cmds), 2)
        self.assertIn(["tmux", "-S", "/tmp/outer", "select-window", "-t",
                       "$0:2"], outer_cmds)
        self.assertIn(["tmux", "-S", "/tmp/inner", "select-window", "-t",
                       "$0:7"], inner_cmds)


class MainIOTests(unittest.TestCase):
    """main() exercised with an injected fake run_query, no real tmux."""

    def test_02_missing_window_exit_4_no_jump_command(self):
        calls = []

        class FakeResult:
            def __init__(self, returncode, stdout=""):
                self.returncode = returncode
                self.stdout = stdout

        def fake_run_query(argv):
            calls.append(argv)
            if "list-sessions" in argv:
                return FakeResult(0, "$0\talpha_c\n")
            if "list-windows" in argv:
                return FakeResult(0, "0\n1\n")  # no window "5"
            raise AssertionError("unexpected query: %r" % (argv,))

        def boom_exec(argv):
            raise AssertionError("no jump command should run")

        code = jump.main(["/some/socket", "alpha_c", "5"],
                          run_query=fake_run_query, run_exec=boom_exec)
        self.assertEqual(code, 4)
        joined = [" ".join(a) for a in calls]
        self.assertFalse(any("switch-client" in c or "select-window" in c
                              or "select-pane" in c for c in joined))
        self.assertFalse(any("list-clients" in c for c in joined))

    def test_03_inner_socket_unreachable_exit_3(self):
        calls = []

        class FakeResult:
            def __init__(self, returncode, stdout=""):
                self.returncode = returncode
                self.stdout = stdout

        def fake_run_query(argv):
            calls.append(argv)
            return FakeResult(1, "")  # every query fails: unreachable socket

        def boom_exec(argv):
            raise AssertionError("no jump command should run")

        code = jump.main(["/no/such/socket", "alpha_c", "1"],
                          run_query=fake_run_query, run_exec=boom_exec)
        self.assertEqual(code, 3)
        self.assertTrue(calls)
        for argv in calls:
            self.assertNotIn("switch-client", argv)
            self.assertNotIn("select-window", argv)
            self.assertNotIn("select-pane", argv)

    def test_04_no_clients_exit_5_outer_untouched(self):
        calls = []

        class FakeResult:
            def __init__(self, returncode, stdout=""):
                self.returncode = returncode
                self.stdout = stdout

        def fake_run_query(argv):
            calls.append(argv)
            if "list-sessions" in argv:
                return FakeResult(0, "$0\talpha_c\n")
            if "list-windows" in argv:
                return FakeResult(0, "0\n1\n")
            if "list-clients" in argv:
                return FakeResult(0, "")  # nobody attached
            raise AssertionError("unexpected query: %r" % (argv,))

        def boom_exec(argv):
            raise AssertionError("no jump command should run")

        code = jump.main(["/some/socket", "alpha_c", "1"],
                          run_query=fake_run_query, run_exec=boom_exec)
        self.assertEqual(code, 5)
        joined = [" ".join(a) for a in calls]
        self.assertFalse(any("display" in c for c in joined))
        self.assertFalse(any("switch-client" in c or "select-window" in c
                              or "select-pane" in c for c in joined))

    def test_10_dry_run_prints_and_executes_nothing(self):
        import io

        class FakeResult:
            def __init__(self, returncode, stdout=""):
                self.returncode = returncode
                self.stdout = stdout

        def fake_run_query(argv):
            if "list-sessions" in argv and "-F" in argv and \
                    "#{session_id}\t#{session_name}" in argv:
                return FakeResult(0, "$0\talpha_c\n")
            if "list-sessions" in argv:
                return FakeResult(0, "$0\n")
            if "list-windows" in argv:
                return FakeResult(0, "0\n2\n")
            if "list-clients" in argv:
                return FakeResult(0, "555\t/dev/pts/9\n")
            raise AssertionError("unexpected query: %r" % (argv,))

        def fake_read_env(pid):
            self.assertEqual(pid, 555)
            return b"TMUX=/tmp/outer,1,0\0TMUX_PANE=%3\0"

        def fake_run_query_with_display(argv):
            if "display" in argv:
                return FakeResult(0, "$1\t2\t1\n")
            return fake_run_query(argv)

        def boom_exec(argv):
            raise AssertionError("--dry-run must execute nothing")

        out = io.StringIO()
        code = jump.main(["--dry-run", "/some/socket", "alpha_c", "2"],
                          run_query=fake_run_query_with_display,
                          run_exec=boom_exec, read_env=fake_read_env,
                          out=out)
        self.assertEqual(code, 0)
        printed = out.getvalue()
        self.assertIn("switch-client -t $1", printed)
        self.assertIn("select-pane -t %3", printed)
        self.assertIn("-S /some/socket select-window -t $0:2", printed)

    def test_11_wrong_arg_count_exit_2(self):
        def boom(argv):
            raise AssertionError("no tmux query should run for a usage error")
        code = jump.main(["only-one-arg"], run_query=boom)
        self.assertEqual(code, 2)
        code = jump.main([], run_query=boom)
        self.assertEqual(code, 2)
        code = jump.main(["a", "b", "c", "d"], run_query=boom)
        self.assertEqual(code, 2)


class EnvironExtractionTests(unittest.TestCase):

    def test_12_extract_only_tmux_and_tmux_pane(self):
        blob = (b"SECRET=x\0"
                b"TMUX=/tmp/outer,1234,0\0"
                b"TMUX_PANE=%7\0"
                b"OTHER=y\0")
        tmux, pane = jump.extract_tmux_vars(blob)
        self.assertEqual(tmux, "/tmp/outer,1234,0")
        self.assertEqual(pane, "%7")
        # The decoy must never surface anywhere in the result.
        self.assertNotIn("x", (tmux, pane))
        self.assertNotIn("SECRET", (tmux, pane))


@unittest.skipUnless(have_tmux(), "tmux not installed")
class RealTmuxTests(unittest.TestCase):
    """Throwaway tmux servers under a temp dir. Always torn down."""

    def test_08_session_names_with_dot_and_colon(self):
        tmp = tempfile.mkdtemp(prefix="claude-attn-jump-test-")
        sock = os.path.join(tmp, "inner")
        name = "alpha.c:beta"  # the exact pair of troublesome characters
        try:
            subprocess.run(["tmux", "-S", sock, "new-session", "-d", "-s",
                             name, "-x", "80", "-y", "24"], check=True)
            # Target the freshly-created session by its id for the setup
            # step too: the raw name contains the very ':' that breaks
            # tmux's own -t parsing, so passing it to -t here would hit
            # the exact bug this test exists to guard against, rather
            # than building the fixture it needs.
            setup_sid = subprocess.run(
                ["tmux", "-S", sock, "list-sessions", "-F", "#{session_id}"],
                capture_output=True, text=True, check=True).stdout.strip()
            subprocess.run(["tmux", "-S", sock, "new-window", "-t",
                             setup_sid], check=True)

            sid = jump.resolve_session_id(sock, name, jump.run_query_default)
            self.assertIsNotNone(sid)
            self.assertTrue(sid.startswith("$"))
            self.assertTrue(jump.window_exists(sock, sid, "1",
                                                jump.run_query_default))
            self.assertFalse(jump.window_exists(sock, sid, "9",
                                                 jump.run_query_default))

            # And a target built from that session_id actually works
            # against the real server -- this is the whole point of
            # resolving to an id instead of threading the raw name
            # through a tmux -t string.
            r = subprocess.run(["tmux", "-S", sock, "select-window", "-t",
                                 "%s:1" % sid])
            self.assertEqual(r.returncode, 0)
        finally:
            subprocess.run(["tmux", "-S", sock, "kill-server"],
                            capture_output=True)
            shutil.rmtree(tmp, ignore_errors=True)

    def test_13_end_to_end_two_servers(self):
        import pty
        import sys
        import time

        tmp = tempfile.mkdtemp(prefix="claude-attn-jump-test-")
        outer = os.path.join(tmp, "outer")
        inner = os.path.join(tmp, "inner")
        procs = []
        try:
            # --- outer server: 2 windows, a real attached client -------
            subprocess.run(["tmux", "-S", outer, "new-session", "-d", "-s",
                             "alpha_c", "-x", "80", "-y", "24"], check=True)
            outer_sid = subprocess.run(
                ["tmux", "-S", outer, "list-sessions", "-F",
                 "#{session_id}"], capture_output=True, text=True,
                check=True).stdout.strip()
            subprocess.run(["tmux", "-S", outer, "new-window", "-t",
                             outer_sid], check=True)
            subprocess.run(["tmux", "-S", outer, "select-window", "-t",
                             "%s:0" % outer_sid], check=True)
            outer_target_pane = subprocess.run(
                ["tmux", "-S", outer, "list-panes", "-t",
                 "%s:1" % outer_sid, "-F", "#{pane_id}"],
                capture_output=True, text=True, check=True).stdout.strip()

            master_a, slave_a = pty.openpty()
            tty_a = os.ttyname(slave_a)
            proc_a = subprocess.Popen(
                ["tmux", "-S", outer, "attach-session", "-t", outer_sid],
                stdin=slave_a, stdout=slave_a, stderr=slave_a,
                start_new_session=True)
            procs.append(proc_a)

            # --- inner server: 2 windows, a real attached "nested"
            # client whose environ carries the outer socket/pane -------
            subprocess.run(["tmux", "-S", inner, "new-session", "-d", "-s",
                             "beta_code", "-x", "80", "-y", "24"], check=True)
            subprocess.run(["tmux", "-S", inner, "new-window", "-t",
                             "beta_code"], check=True)

            master_b, slave_b = pty.openpty()
            env_b = dict(os.environ)
            env_b["TMUX"] = "%s,0,0" % outer
            env_b["TMUX_PANE"] = outer_target_pane
            proc_b = subprocess.Popen(
                ["tmux", "-S", inner, "attach-session", "-t", "beta_code"],
                stdin=slave_b, stdout=slave_b, stderr=slave_b, env=env_b,
                start_new_session=True)
            procs.append(proc_b)

            # Wait for both clients to actually register (poll, no
            # fixed sleep chain).
            deadline = time.time() + 5
            while time.time() < deadline:
                ra = subprocess.run(["tmux", "-S", outer, "list-clients",
                                      "-t", outer_sid],
                                     capture_output=True, text=True)
                rb = subprocess.run(["tmux", "-S", inner, "list-clients",
                                      "-t", "beta_code"],
                                     capture_output=True, text=True)
                if ra.stdout.strip() and rb.stdout.strip():
                    break
                time.sleep(0.1)
            else:
                self.fail("inner/outer client never registered")

            # --- the real jump: run the actual built binary, with its
            # own stdio attached to client A's tty so tmux's implicit
            # "current client" resolution on the outer socket matches it.
            fd = os.open(tty_a, os.O_RDWR)
            try:
                result = subprocess.run(
                    [sys.executable, SCRIPT, inner, "beta_code", "1"],
                    stdin=fd, stdout=fd, stderr=fd)
            finally:
                os.close(fd)
            self.assertEqual(result.returncode, 0)

            outer_window = subprocess.run(
                ["tmux", "-S", outer, "display-message", "-t", outer_sid,
                 "-p", "#{window_index}"],
                capture_output=True, text=True, check=True).stdout.strip()
            inner_window = subprocess.run(
                ["tmux", "-S", inner, "display-message", "-t", "beta_code",
                 "-p", "#{window_index}"],
                capture_output=True, text=True, check=True).stdout.strip()
            self.assertEqual(outer_window, "1")
            self.assertEqual(inner_window, "1")
        finally:
            for p in procs:
                p.terminate()
                try:
                    p.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    p.kill()
                    p.wait(timeout=2)
            subprocess.run(["tmux", "-S", outer, "kill-server"],
                            capture_output=True)
            subprocess.run(["tmux", "-S", inner, "kill-server"],
                            capture_output=True)
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
