"""Tests for evals.framework.setup — fixture setup, repo setup, and baseline verification.

RED phase: all tests must fail because the implementation is stubbed.

Acceptance criteria covered:
  AC-6: setup_fixture(fixture_path, workdir) copies fixture dir to workdir.
        Original not modified. Raises FileNotFoundError if fixture_path doesn't exist.
  AC-7: setup_repo(repo, base_commit, workdir, install_command) clones repo,
        checks out commit, runs install. Raises exception with stderr on failure.
  AC-8: verify_baseline(workdir, fail_to_pass, test_command) runs test command,
        returns False if tests pass (exit 0), True if they fail (non-zero exit).
"""

import subprocess
import unittest
from unittest.mock import patch, call, MagicMock

from evals.framework.setup import setup_fixture, setup_repo, verify_baseline


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _mock_run_success(stdout="", stderr="", returncode=0):
    """Return a MagicMock resembling a successful subprocess.CompletedProcess."""
    result = MagicMock()
    result.stdout = stdout
    result.stderr = stderr
    result.returncode = returncode
    return result


def _mock_run_failure(stderr="fatal error", returncode=1):
    """Return a MagicMock resembling a failed subprocess.CompletedProcess."""
    result = MagicMock()
    result.stdout = ""
    result.stderr = stderr
    result.returncode = returncode
    return result


# ===========================================================================
# AC-6: setup_fixture copies fixture directory to workdir
# ===========================================================================

class TestSetupFixtureCopiesDirectory(unittest.TestCase):
    """AC-6: setup_fixture copies fixture_path contents to workdir."""

    @patch("evals.framework.setup.shutil.copytree")
    @patch("evals.framework.setup.os.path.isdir", return_value=True)
    def test_copies_fixture_to_workdir(self, mock_isdir, mock_copytree):
        setup_fixture("/fixtures/basic", "/tmp/workdir")
        mock_copytree.assert_called_once_with("/fixtures/basic", "/tmp/workdir")

    @patch("evals.framework.setup.shutil.copytree")
    @patch("evals.framework.setup.os.path.isdir", return_value=True)
    def test_copies_different_paths_not_hardcoded(self, mock_isdir, mock_copytree):
        """Guards against hardcoded paths in the implementation."""
        setup_fixture("/other/fixture", "/other/workdir")
        mock_copytree.assert_called_once_with("/other/fixture", "/other/workdir")

    @patch("evals.framework.setup.shutil.copytree")
    @patch("evals.framework.setup.os.path.isdir", return_value=True)
    def test_returns_none_on_success(self, mock_isdir, mock_copytree):
        result = setup_fixture("/fixtures/basic", "/tmp/workdir")
        self.assertIsNone(result)


class TestSetupFixtureOriginalNotModified(unittest.TestCase):
    """AC-6: Original fixture directory is not modified."""

    @patch("evals.framework.setup.shutil.copytree")
    @patch("evals.framework.setup.os.path.isdir", return_value=True)
    def test_does_not_delete_or_move_original(self, mock_isdir, mock_copytree):
        """copytree is a copy, not a move. No rmtree or rename on the source."""
        with patch("evals.framework.setup.shutil.rmtree") as mock_rmtree, \
             patch("evals.framework.setup.os.rename") as mock_rename, \
             patch("evals.framework.setup.shutil.move") as mock_move:
            setup_fixture("/fixtures/basic", "/tmp/workdir")
            mock_rmtree.assert_not_called()
            mock_rename.assert_not_called()
            mock_move.assert_not_called()

    @patch("evals.framework.setup.shutil.copytree")
    @patch("evals.framework.setup.os.path.isdir", return_value=True)
    def test_uses_copytree_not_move(self, mock_isdir, mock_copytree):
        """Ensure we're copying, not moving. copytree must be called, move must not."""
        setup_fixture("/fixtures/basic", "/tmp/workdir")
        self.assertTrue(mock_copytree.called, "copytree must be called for copying")


class TestSetupFixtureFileNotFound(unittest.TestCase):
    """AC-6: Raises FileNotFoundError when fixture_path doesn't exist."""

    @patch("evals.framework.setup.os.path.isdir", return_value=False)
    def test_raises_file_not_found_error_when_path_missing(self, mock_isdir):
        with self.assertRaises(FileNotFoundError):
            setup_fixture("/nonexistent/path", "/tmp/workdir")

    @patch("evals.framework.setup.os.path.isdir", return_value=False)
    def test_error_message_includes_fixture_path(self, mock_isdir):
        """Error should mention which path was not found."""
        with self.assertRaises(FileNotFoundError) as ctx:
            setup_fixture("/missing/fixture", "/tmp/workdir")
        self.assertIn("/missing/fixture", str(ctx.exception))

    @patch("evals.framework.setup.shutil.copytree")
    @patch("evals.framework.setup.os.path.isdir", return_value=False)
    def test_does_not_call_copytree_when_path_missing(self, mock_isdir, mock_copytree):
        """Must not attempt to copy a nonexistent directory."""
        with self.assertRaises(FileNotFoundError):
            setup_fixture("/nonexistent/path", "/tmp/workdir")
        mock_copytree.assert_not_called()


# ===========================================================================
# AC-7: setup_repo clones repo, checks out commit, runs install
# ===========================================================================

class TestSetupRepoClone(unittest.TestCase):
    """AC-7: setup_repo clones the given repo to workdir."""

    @patch("evals.framework.setup.subprocess.run")
    def test_calls_git_clone_with_repo_and_workdir(self, mock_run):
        mock_run.return_value = _mock_run_success()
        setup_repo("https://github.com/org/repo.git", "abc123", "/tmp/workdir")

        # Find the git clone call among all calls
        clone_calls = [
            c for c in mock_run.call_args_list
            if "clone" in str(c)
        ]
        self.assertEqual(len(clone_calls), 1, "Exactly one git clone call expected")
        clone_args = clone_calls[0][0][0]  # positional arg 0 is the command list
        self.assertIn("git", clone_args)
        self.assertIn("clone", clone_args)
        self.assertIn("https://github.com/org/repo.git", clone_args)
        self.assertIn("/tmp/workdir", clone_args)

    @patch("evals.framework.setup.subprocess.run")
    def test_uses_different_repo_url_not_hardcoded(self, mock_run):
        """Guards against hardcoded repo URLs."""
        mock_run.return_value = _mock_run_success()
        setup_repo("https://github.com/other/project.git", "def456", "/tmp/work2")

        clone_calls = [
            c for c in mock_run.call_args_list
            if "clone" in str(c)
        ]
        self.assertEqual(len(clone_calls), 1)
        clone_args = clone_calls[0][0][0]
        self.assertIn("https://github.com/other/project.git", clone_args)
        self.assertIn("/tmp/work2", clone_args)


class TestSetupRepoCheckout(unittest.TestCase):
    """AC-7: setup_repo checks out the specified base_commit."""

    @patch("evals.framework.setup.subprocess.run")
    def test_calls_git_checkout_with_commit(self, mock_run):
        mock_run.return_value = _mock_run_success()
        setup_repo("https://github.com/org/repo.git", "abc123", "/tmp/workdir")

        checkout_calls = [
            c for c in mock_run.call_args_list
            if "checkout" in str(c)
        ]
        self.assertEqual(len(checkout_calls), 1, "Exactly one git checkout call expected")
        checkout_args = checkout_calls[0][0][0]
        self.assertIn("git", checkout_args)
        self.assertIn("checkout", checkout_args)
        self.assertIn("abc123", checkout_args)

    @patch("evals.framework.setup.subprocess.run")
    def test_checkout_uses_different_commit_not_hardcoded(self, mock_run):
        """Guards against hardcoded commit hashes."""
        mock_run.return_value = _mock_run_success()
        setup_repo("https://github.com/org/repo.git", "xyz789", "/tmp/workdir")

        checkout_calls = [
            c for c in mock_run.call_args_list
            if "checkout" in str(c)
        ]
        self.assertEqual(len(checkout_calls), 1)
        checkout_args = checkout_calls[0][0][0]
        self.assertIn("xyz789", checkout_args)

    @patch("evals.framework.setup.subprocess.run")
    def test_checkout_runs_in_workdir(self, mock_run):
        """git checkout must execute inside the cloned workdir."""
        mock_run.return_value = _mock_run_success()
        setup_repo("https://github.com/org/repo.git", "abc123", "/tmp/workdir")

        checkout_calls = [
            c for c in mock_run.call_args_list
            if "checkout" in str(c)
        ]
        self.assertEqual(len(checkout_calls), 1)
        checkout_kwargs = checkout_calls[0][1]
        self.assertEqual(checkout_kwargs.get("cwd"), "/tmp/workdir")

    @patch("evals.framework.setup.subprocess.run")
    def test_clone_runs_before_checkout(self, mock_run):
        """Clone must happen before checkout (ordering matters)."""
        mock_run.return_value = _mock_run_success()
        setup_repo("https://github.com/org/repo.git", "abc123", "/tmp/workdir")

        call_list = mock_run.call_args_list
        clone_idx = None
        checkout_idx = None
        for i, c in enumerate(call_list):
            args_str = str(c)
            if "clone" in args_str:
                clone_idx = i
            if "checkout" in args_str:
                checkout_idx = i

        self.assertIsNotNone(clone_idx, "git clone must be called")
        self.assertIsNotNone(checkout_idx, "git checkout must be called")
        self.assertLess(clone_idx, checkout_idx, "clone must happen before checkout")


class TestSetupRepoInstallCommand(unittest.TestCase):
    """AC-7: setup_repo runs install_command when provided."""

    @patch("evals.framework.setup.subprocess.run")
    def test_runs_install_command_when_provided(self, mock_run):
        mock_run.return_value = _mock_run_success()
        setup_repo(
            "https://github.com/org/repo.git", "abc123", "/tmp/workdir",
            install_command="npm install",
        )

        install_calls = [
            c for c in mock_run.call_args_list
            if "npm install" in str(c) or "npm" in str(c)
        ]
        self.assertGreaterEqual(
            len(install_calls), 1,
            "install_command must be executed",
        )

    @patch("evals.framework.setup.subprocess.run")
    def test_install_command_runs_in_workdir(self, mock_run):
        mock_run.return_value = _mock_run_success()
        setup_repo(
            "https://github.com/org/repo.git", "abc123", "/tmp/workdir",
            install_command="pip install -e .",
        )

        # Last call should be the install command
        install_calls = [
            c for c in mock_run.call_args_list
            if "pip" in str(c) or "install" in str(c) and "clone" not in str(c)
        ]
        # At least one install call must have cwd set to workdir
        found_cwd = False
        for c in install_calls:
            if c[1].get("cwd") == "/tmp/workdir":
                found_cwd = True
        self.assertTrue(found_cwd, "install command must run in workdir")

    @patch("evals.framework.setup.subprocess.run")
    def test_no_install_call_when_install_command_is_none(self, mock_run):
        mock_run.return_value = _mock_run_success()
        setup_repo(
            "https://github.com/org/repo.git", "abc123", "/tmp/workdir",
            install_command=None,
        )

        # Should have exactly 2 calls: clone + checkout (no install)
        self.assertEqual(
            mock_run.call_count, 2,
            "Only git clone and git checkout should be called when install_command is None",
        )

    @patch("evals.framework.setup.subprocess.run")
    def test_install_runs_after_checkout(self, mock_run):
        """Install must happen after clone+checkout."""
        mock_run.return_value = _mock_run_success()
        setup_repo(
            "https://github.com/org/repo.git", "abc123", "/tmp/workdir",
            install_command="make install",
        )

        call_list = mock_run.call_args_list
        checkout_idx = None
        install_idx = None
        for i, c in enumerate(call_list):
            args_str = str(c)
            if "checkout" in args_str:
                checkout_idx = i
            if "make" in args_str:
                install_idx = i

        self.assertIsNotNone(checkout_idx, "git checkout must be called")
        self.assertIsNotNone(install_idx, "install command must be called")
        self.assertLess(checkout_idx, install_idx, "install must happen after checkout")


class TestSetupRepoFailure(unittest.TestCase):
    """AC-7: Raises exception with stderr on subprocess failure."""

    @patch("evals.framework.setup.subprocess.run")
    def test_raises_on_clone_failure(self, mock_run):
        mock_run.side_effect = subprocess.CalledProcessError(
            returncode=128,
            cmd=["git", "clone"],
            stderr="fatal: repository not found",
        )
        with self.assertRaises(Exception) as ctx:
            setup_repo("https://github.com/org/bad.git", "abc123", "/tmp/workdir")
        self.assertIn("repository not found", str(ctx.exception))

    @patch("evals.framework.setup.subprocess.run")
    def test_raises_on_checkout_failure(self, mock_run):
        """Clone succeeds, but checkout of bad commit fails."""
        def side_effect(*args, **kwargs):
            cmd = args[0] if args else kwargs.get("args", [])
            if "checkout" in cmd:
                raise subprocess.CalledProcessError(
                    returncode=1,
                    cmd=cmd,
                    stderr="error: pathspec 'badcommit' did not match",
                )
            return _mock_run_success()

        mock_run.side_effect = side_effect
        with self.assertRaises(Exception) as ctx:
            setup_repo("https://github.com/org/repo.git", "badcommit", "/tmp/workdir")
        self.assertIn("badcommit", str(ctx.exception))

    @patch("evals.framework.setup.subprocess.run")
    def test_raises_on_install_failure(self, mock_run):
        """Clone and checkout succeed, but install command fails."""
        call_count = [0]

        def side_effect(*args, **kwargs):
            call_count[0] += 1
            cmd = args[0] if args else kwargs.get("args", [])
            # First two calls (clone, checkout) succeed; third (install) fails
            if call_count[0] <= 2:
                return _mock_run_success()
            raise subprocess.CalledProcessError(
                returncode=1,
                cmd=cmd,
                stderr="npm ERR! install failed",
            )

        mock_run.side_effect = side_effect
        with self.assertRaises(Exception) as ctx:
            setup_repo(
                "https://github.com/org/repo.git", "abc123", "/tmp/workdir",
                install_command="npm install",
            )
        self.assertIn("install failed", str(ctx.exception))

    @patch("evals.framework.setup.subprocess.run")
    def test_exception_includes_stderr_content(self, mock_run):
        """The raised exception must contain the stderr from the failed command."""
        mock_run.side_effect = subprocess.CalledProcessError(
            returncode=128,
            cmd=["git", "clone"],
            stderr="Permission denied (publickey)",
        )
        with self.assertRaises(Exception) as ctx:
            setup_repo("https://github.com/org/private.git", "abc123", "/tmp/workdir")
        self.assertIn("Permission denied", str(ctx.exception))

    @patch("evals.framework.setup.subprocess.run")
    def test_does_not_silently_return_none_on_failure(self, mock_run):
        """A bad impl might catch the error and return None. Must raise."""
        mock_run.side_effect = subprocess.CalledProcessError(
            returncode=1,
            cmd=["git", "clone"],
            stderr="connection refused",
        )
        raised = False
        try:
            setup_repo("https://github.com/org/repo.git", "abc123", "/tmp/workdir")
        except Exception:
            raised = True
        self.assertTrue(raised, "Must raise an exception on subprocess failure, not return None")


# ===========================================================================
# AC-8: verify_baseline runs test command and checks exit code
# ===========================================================================

class TestVerifyBaselineTestsFail(unittest.TestCase):
    """AC-8: Returns True when tests fail as expected (non-zero exit)."""

    @patch("evals.framework.setup.subprocess.run")
    def test_returns_true_when_tests_fail_exit_1(self, mock_run):
        mock_run.return_value = _mock_run_failure(returncode=1)
        result = verify_baseline(
            workdir="/tmp/workdir",
            fail_to_pass=["test_something"],
            test_command="pytest",
        )
        self.assertIs(result, True)

    @patch("evals.framework.setup.subprocess.run")
    def test_returns_true_when_tests_fail_exit_2(self, mock_run):
        """Any non-zero exit is a valid failure."""
        mock_run.return_value = _mock_run_failure(returncode=2)
        result = verify_baseline(
            workdir="/tmp/workdir",
            fail_to_pass=["test_something"],
            test_command="pytest",
        )
        self.assertIs(result, True)


class TestVerifyBaselineTestsPass(unittest.TestCase):
    """AC-8: Returns False when tests unexpectedly pass (exit 0)."""

    @patch("evals.framework.setup.subprocess.run")
    def test_returns_false_when_tests_pass_exit_0(self, mock_run):
        mock_run.return_value = _mock_run_success(returncode=0)
        result = verify_baseline(
            workdir="/tmp/workdir",
            fail_to_pass=["test_something"],
            test_command="pytest",
        )
        self.assertIs(result, False)


class TestVerifyBaselineCommandExecution(unittest.TestCase):
    """AC-8: verify_baseline actually runs the test command."""

    @patch("evals.framework.setup.subprocess.run")
    def test_runs_test_command(self, mock_run):
        mock_run.return_value = _mock_run_failure(returncode=1)
        verify_baseline(
            workdir="/tmp/workdir",
            fail_to_pass=["test_something"],
            test_command="pytest -x tests/",
        )
        mock_run.assert_called_once()

    @patch("evals.framework.setup.subprocess.run")
    def test_runs_command_in_workdir(self, mock_run):
        mock_run.return_value = _mock_run_failure(returncode=1)
        verify_baseline(
            workdir="/tmp/workdir",
            fail_to_pass=["test_something"],
            test_command="pytest",
        )
        call_kwargs = mock_run.call_args[1]
        self.assertEqual(call_kwargs.get("cwd"), "/tmp/workdir")

    @patch("evals.framework.setup.subprocess.run")
    def test_uses_provided_test_command_not_hardcoded(self, mock_run):
        """Guards against ignoring the test_command parameter."""
        mock_run.return_value = _mock_run_failure(returncode=1)
        verify_baseline(
            workdir="/tmp/workdir",
            fail_to_pass=["test_foo"],
            test_command="npm test",
        )
        cmd_arg = mock_run.call_args[0][0]
        # The command should contain "npm test" either as a string or in a list
        cmd_str = cmd_arg if isinstance(cmd_arg, str) else " ".join(cmd_arg)
        self.assertIn("npm test", cmd_str)

    @patch("evals.framework.setup.subprocess.run")
    def test_different_test_commands_produce_different_calls(self, mock_run):
        """Guards against hardcoded test commands."""
        mock_run.return_value = _mock_run_failure(returncode=1)

        verify_baseline("/tmp/w1", ["test_a"], "pytest")
        first_cmd = mock_run.call_args[0][0]

        mock_run.reset_mock()
        mock_run.return_value = _mock_run_failure(returncode=1)

        verify_baseline("/tmp/w2", ["test_b"], "cargo test")
        second_cmd = mock_run.call_args[0][0]

        first_str = first_cmd if isinstance(first_cmd, str) else " ".join(first_cmd)
        second_str = second_cmd if isinstance(second_cmd, str) else " ".join(second_cmd)
        self.assertNotEqual(first_str, second_str)


class TestVerifyBaselineReturnType(unittest.TestCase):
    """AC-8: Return value is strictly boolean, not truthy/falsy."""

    @patch("evals.framework.setup.subprocess.run")
    def test_returns_bool_true_not_truthy_integer(self, mock_run):
        mock_run.return_value = _mock_run_failure(returncode=1)
        result = verify_baseline("/tmp/workdir", ["test_x"], "pytest")
        self.assertIsInstance(result, bool)
        self.assertIs(result, True)

    @patch("evals.framework.setup.subprocess.run")
    def test_returns_bool_false_not_falsy_zero(self, mock_run):
        mock_run.return_value = _mock_run_success(returncode=0)
        result = verify_baseline("/tmp/workdir", ["test_x"], "pytest")
        self.assertIsInstance(result, bool)
        self.assertIs(result, False)


if __name__ == "__main__":
    unittest.main()
