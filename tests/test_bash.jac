"""A Bash launcher on PATH is not necessarily a usable shell (Windows WSL)."""

import from pathlib { Path }

import subprocess;

import unittest;

import from unittest { mock }

class BashDiscoveryTests(unittest.TestCase) {
    def test_working_path_shell_is_used -> any;

    def test_launcher_that_expands_variables_falls_back_to_git_bash -> any;

    def test_missing_shell_needs_no_probe -> any;

    def test_unusable_path_shell_falls_back_to_git_bash_on_windows -> any;

    def test_failed_or_hanging_shell_is_unavailable -> any;

    def test_nonzero_exit_without_a_fallback_is_unavailable -> any;
}
