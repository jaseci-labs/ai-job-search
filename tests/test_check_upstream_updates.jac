import os;
import shutil;
import subprocess;
import tempfile;
import unittest;
import from pathlib { Path }

glob REPO_ROOT: Path = Path(__file__).resolve().parent.parent,
     TEMPLATE_URL: str = "https://github.com/ai-job-search-dev/ai-job-search.git",
     FORK_URL: str = "https://github.com/octocat/ai-job-search.git",
     FRAMEWORK_FILES: list[str] = [
         f".claude/skills/job-application-assistant/{name}.md"
         for name in ("01-candidate-profile 02-behavioral-profile 03-writing-style 04-job-evaluation"
             " 05-cv-templates 06-cover-letter-templates 07-interview-prep"
             " 08-application-forms 09-web-research SKILL").split()
     ] + ["AGENTS.md"],
     FRONTMATTER: str = "---\nframework_version: 1.0.0\n---\n",
     FALLBACK: str = "Falling back to 'origin'",
     NOT_TEMPLATE: str = "does not point to the ai-job-search template repo";

class UpstreamCheckerRepoFixture(unittest.TestCase) {
    def setUp -> None;
    def new_repo -> None;
    def git(*args: str) -> subprocess.CompletedProcess;
    def commit(message: str) -> None;
    def add_remote(name: str, url: str) -> None;
    def materialize_remote_ref(name: str) -> None;
    def with_remotes(urls: dict[str, str]) -> None;
    def run_checker(
        *args: str, fetch: bool = False, env: dict[str, str] | None = None
    ) -> subprocess.CompletedProcess;
    def check(result: subprocess.CompletedProcess, shows: list[str], lacks: list[str] = []) -> str;
}

class UpstreamCheckerTests(UpstreamCheckerRepoFixture) {
    def stale_upstream(message: str) -> None;
    def assert_incomplete -> None;
    def test_remote_fallback_and_fork_warning;
    def test_cached_ref_after_failed_fetch_is_not_reported_as_current;
    def test_file_missing_upstream_is_reported_instead_of_silent_ok;
    def test_missing_local_file_does_not_report_all_files_up_to_date;
    def test_missing_upstream_marker_does_not_report_all_files_up_to_date;
    def test_output_is_utf8_under_a_legacy_locale;
}
