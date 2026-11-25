"""Guards for tools/check_framework_version.jac - the CI gate itself.

This gate is what stops a PR from editing a profile-bearing framework
file without bumping `framework_version` (the fork-rebase safety marker).
It ran in CI with zero tests, so a one-line mutation
(`return meaningful_changes > 0` -> `return False`) disabled it while
the whole suite stayed green (review finding F22, 2026-08-19). A broken
guard is silent by construction: nothing fails, it just stops catching.

Each test builds an isolated git repo with the script copied inside it
(the script resolves ROOT from __file__), so the real repo is never read
or written.
"""

import os;

import shutil;

import subprocess;

import sys;

import tempfile;

import unittest;

import unittest.mock;

import from pathlib { Path, PureWindowsPath }

glob REPO_ROOT: any;

glob FRONTMATTER: any;

glob BODY: any;

with entry {
    REPO_ROOT = Path(__file__).resolve().parent.parent;
    FRONTMATTER = "---\nframework_version: 1.0.0\n---\n";
    BODY = "# Test framework file\n\nOriginal guidance sentence.\n";
}

class CheckerRepoFixture(unittest.TestCase) {
    def setUp -> any;

    def git(*args_) -> any;

    def run_checker -> any;
}

class FrameworkVersionGateTests(CheckerRepoFixture) {
    def test_clean_tree_passes -> any;

    def test_unbumped_edit_fails -> any;

    def test_bumped_edit_passes -> any;

    def test_same_version_reformatted_does_not_count_as_a_bump -> any;

    def test_reformatting_version_alone_remains_allowed -> any;

    def test_file_without_version_marker_fails -> any;
}

class WindowsGitPathTests(unittest.TestCase) {
    def test_diff_and_show_use_posix_paths_for_windows_checkout -> any;
}

"""run_git() must decode `git diff` output as UTF-8 explicitly, not via
    whatever `subprocess.run(text=True)` falls back to on the host locale.

    On a real Windows checkout, the un-pinned call decodes as cp1252 (the
    locale default there) and a byte cp1252 leaves undefined - e.g.
    Cyrillic Ё/ё, much CJK, or Á-class Latin - in a framework file's diff
    raises UnicodeDecodeError before the gate ever evaluates the change
    (reported 2026-10-01, reproduced on Windows with Cyrillic Ё). An em
    dash does not trigger this - cp1252 maps it fine. `LC_ALL`/`LANG` don't
    influence this on Windows, so the regression is pinned directly against
    the subprocess.run() call rather than by trying to simulate the OS
    locale."""
class RunGitEncodingTests(unittest.TestCase) {
    def test_run_git_pins_utf8_encoding -> any;
}

with entry:__main__ {
    unittest.main();
}
