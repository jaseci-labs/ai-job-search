import os;
import subprocess;
import unittest;
import from unittest { mock }

glob UPSTREAM: str = "ai-job-search-dev/ai-job-search",
     ORIGIN_URLS: dict[str, bool] = {
         "https://github.com/ai-job-search-dev/ai-job-search": True,
         "https://github.com/ai-job-search-dev/ai-job-search.git": True,
         "git@github.com:ai-job-search-dev/ai-job-search": True,
         "git@github.com:ai-job-search-dev/ai-job-search.git": True,
         "ssh://git@github.com/ai-job-search-dev/ai-job-search.git": True,
         "ssh://git@github.com/ai-job-search-dev/ai-job-search": True,
         "ssh://git@github.com/someone-else/ai-job-search.git": False,
         "https://github.com/someone-else/ai-job-search.git": False,
         "git@github.com:someone-else/ai-job-search": False,
         "git@github.com:someone-else/ai-job-search.git": False,
         "https://gitlab.com/ai-job-search-dev/ai-job-search.git": False,
     };

def completed(stdout: str = "", returncode: int = 0) -> subprocess.CompletedProcess;

class UpstreamCheckoutTests(unittest.TestCase) {
    def test_github_repository_decides_without_asking_git;
    def test_origin_decides_when_no_env_and_unknown_means_upstream;
}
