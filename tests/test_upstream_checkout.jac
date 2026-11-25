import os;

import subprocess;

import unittest;

import from unittest { mock }

glob UPSTREAM: any = "ai-job-search-dev/ai-job-search";

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
