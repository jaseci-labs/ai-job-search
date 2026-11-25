import os;
import shutil;
import subprocess;
import tempfile;
import unittest;
import from pathlib { Path, PureWindowsPath }
import from unittest { mock }

glob FRONTMATTER: str = "---\nframework_version: 1.0.0\n---\n",
     BODY: str = "# Test framework file\n\nOriginal guidance sentence.\n",
     PROFILE: str = ".claude/skills/job-application-assistant/01-test-profile.md";

class CheckerRepoFixture(unittest.TestCase) {
    def setUp -> None;
    def run_checker -> subprocess.CompletedProcess;
}

class FrameworkVersionGateTests(CheckerRepoFixture) {
    def test_edits_need_a_version_bump;
    def test_file_without_version_marker_fails;
}

class GitCallTests(unittest.TestCase) {
    def test_diff_and_show_use_posix_paths_for_windows_checkout;
    def test_run_git_pins_utf8_encoding;
}
