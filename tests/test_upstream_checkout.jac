"""Unit tests for the shared fork-detection helper (issue #496).

The placeholder guards must skip on personalized forks even in a local run
where GITHUB_REPOSITORY is unset. All branches are exercised with the env
and subprocess.run patched, so no git remote or CI variable is needed.
"""

import os;

import subprocess;

import unittest;

import from unittest { mock }

glob UPSTREAM: any = "ai-job-search-dev/ai-job-search";

"""Clear GITHUB_REPOSITORY so the origin-remote branch is exercised."""
def _no_github_env(testcase) -> any;

def _completed(stdout="", returncode=0) -> any;

class UpstreamCheckoutTests(unittest.TestCase) {
    def test_env_says_upstream -> any;

    def test_env_says_fork -> any;

    def test_no_env_and_origin_is_fork -> any;

    def test_no_env_and_git_is_unavailable -> any;

    def test_no_env_and_git_times_out -> any;

    def test_no_env_and_git_exits_nonzero -> any;

    def test_origin_url_forms -> any;
}

with entry:__main__ {
    unittest.main();
}
