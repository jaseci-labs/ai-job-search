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

class RunGitEncodingTests(unittest.TestCase) {
    def test_run_git_pins_utf8_encoding -> any;
}

with entry:__main__ {
    unittest.main();
}
