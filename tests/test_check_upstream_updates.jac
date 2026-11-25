import builtins;

import os;

import shutil;

import subprocess;

import sys;

import tempfile;

import unittest;

import from pathlib { Path }

glob REPO_ROOT: any;

glob TEMPLATE_URL: any;

glob FORK_URL: any;

glob FRAMEWORK_FILES: any;

glob FRONTMATTER: any;

with entry {
    REPO_ROOT = Path(__file__).resolve().parent.parent;
    TEMPLATE_URL = "https://github.com/ai-job-search-dev/ai-job-search.git";
    FORK_URL = "https://github.com/octocat/ai-job-search.git";

    FRAMEWORK_FILES = [
        ".claude/skills/job-application-assistant/01-candidate-profile.md",
        ".claude/skills/job-application-assistant/02-behavioral-profile.md",
        ".claude/skills/job-application-assistant/03-writing-style.md",
        ".claude/skills/job-application-assistant/04-job-evaluation.md",
        ".claude/skills/job-application-assistant/05-cv-templates.md",
        ".claude/skills/job-application-assistant/06-cover-letter-templates.md",
        ".claude/skills/job-application-assistant/07-interview-prep.md",
        ".claude/skills/job-application-assistant/08-application-forms.md",
        ".claude/skills/job-application-assistant/09-web-research.md",
        ".claude/skills/job-application-assistant/SKILL.md",
        "AGENTS.md",
    ];

    FRONTMATTER = "---\nframework_version: 1.0.0\n---\n";
}

class UpstreamCheckerRepoFixture(unittest.TestCase) {
    def setUp -> any;

    def add_remote(name: builtins.str, url: builtins.str) -> None;

    def materialize_remote_ref(name: builtins.str) -> None;

    def run_checker(*args_) -> subprocess.CompletedProcess;

    def run_checker_with_fetch(*args__) -> subprocess.CompletedProcess;
}

class ForkWithoutUpstreamRemoteTests(UpstreamCheckerRepoFixture) {
    def setUp -> any;

    def test_fork_fallback_warns_that_check_is_against_own_fork -> any;
}

class DirectCloneFallbackTests(UpstreamCheckerRepoFixture) {
    def setUp -> any;

    def test_clone_of_template_falls_back_without_fork_warning -> any;

    def test_clone_with_lowercased_template_url_falls_back_without_fork_warning -> any;
}

class UpstreamRemotePresentTests(UpstreamCheckerRepoFixture) {
    def setUp -> any;

    def test_explicit_upstream_remote_is_used_without_warning -> any;
}

class FailedFetchTests(UpstreamCheckerRepoFixture) {
    def test_cached_ref_after_failed_fetch_is_not_reported_as_current -> any;
}

class UpstreamRefMissingFileTests(UpstreamCheckerRepoFixture) {
    def setUp -> any;

    def test_file_missing_upstream_is_reported_instead_of_silent_ok -> any;
}

class LegacyEncodingTests(UpstreamCheckerRepoFixture) {
    def setUp -> any;

    def run_legacy_checker(*args___, ascii_git_codec=True) -> any;

    def test_actual_framework_prose_is_decoded_as_utf8 -> any;

    def test_non_latin_branch_is_printed_as_utf8 -> any;
}

class IncompleteComparisonTests(UpstreamCheckerRepoFixture) {
    def setUp -> any;

    def test_missing_local_file_does_not_report_all_files_up_to_date -> any;

    def test_missing_upstream_marker_does_not_report_all_files_up_to_date -> any;
}

with entry:__main__ {
    unittest.main();
}
