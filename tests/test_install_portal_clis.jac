"""Tests for tools/install_portal_clis.jac - the one-command portal CLI install.

No network and no real `bun install`: discovery and the safety gate run against
a temporary skills tree, the runner is injected, and the end-to-end cases run
the script with --dry-run from a temporary checkout with no portals and with
one copied in.
"""

import builtins;

import from jaclang.comptime { target }

import io;

import json;

import shutil;

import subprocess;

import sys;

import unittest;

import from contextlib { redirect_stdout }

import from pathlib { Path }

import from tempfile { TemporaryDirectory }

glob REPO_ROOT: any;

with entry {
    REPO_ROOT = Path(__file__).resolve().parents[1];
}

def install(*args_) -> any;

class FakeRun(builtins.object) {
    def init(fail=());

    def __call__(argv, cwd) -> any;
}

class InstallPortalClis(unittest.TestCase) {
    def setUp -> any;

    def add_cli(name, manifest=None) -> any;

    """A fork-added portal is found without editing any list."""
    def test_discovers_every_cli_on_the_ci_glob -> any;

    def test_lifecycle_script_is_skipped_not_run -> any;

    def test_trusted_dependencies_is_unsafe -> any;
    def test_workspaces_is_unsafe -> any;

    def test_bunfig_is_unsafe -> any;

    def test_npmrc_is_unsafe -> any;

    def test_bun_install_never_runs_lifecycle_scripts -> any;

    def test_one_failure_does_not_stop_the_rest -> any;

    def test_dry_run_runs_nothing -> any;

    def run_script -> any;

    def test_cli_with_no_portals_installed_succeeds -> any;

    def test_cli_dry_run_lists_a_copied_in_portal -> any;
}

class FindBun(unittest.TestCase) {
    def setUp -> any;

    def test_find_bun_prefers_path -> any;

    def test_find_bun_falls_back_to_candidate_directory -> any;

    def test_find_bun_returns_none_when_missing -> any;

    def test_missing_bun_message_suggests_export -> any;
}

with entry:__main__ {
    unittest.main();
}
