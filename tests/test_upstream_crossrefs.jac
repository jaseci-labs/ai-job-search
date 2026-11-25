import re;
import shlex;
import subprocess;

glob REMOTE: str = "forks/template",
     BRANCHES: tuple[str, ...] = ("release/next", "release'next");

class CompanionRefTests(UpstreamCheckerRepoFixture) {
    def prepare(branch: str) -> list[str];
    def run_tool(name: str, *args: str) -> str;
    def follow(command: str) -> str;
    def test_version_checker_companion_uses_selected_remote_and_branch;
    def test_triage_companion_uses_selected_remote_and_branch;
}
