"""Report framework files whose 'framework_version' is newer in the upstream repository.

Usage: neojac run jobsearch -- check_upstream_updates [--remote <remote-name>] [--branch <branch-name>]

Fetches the upstream remote (default 'upstream', falling back to 'origin') and compares
the version stamps of the local framework files with those at the upstream ref.
"""

import argparse;
import os;
import re;
import shlex;
import subprocess;
import sys;
import from pathlib { Path }

glob ROOT: Path = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent),
     FRAMEWORK_FILES: list[str] = [
         f".claude/skills/job-application-assistant/{name}.md"
         for name in (
             "01-candidate-profile 02-behavioral-profile 03-writing-style 04-job-evaluation"
                 " 05-cv-templates 06-cover-letter-templates 07-interview-prep"
                 " 08-application-forms 09-web-research SKILL"
         ).split()
     ]
         + ["AGENTS.md"],
     UPSTREAM_REPO_SLUG: str = "ai-job-search-dev/ai-job-search";

def run_git(args: list[str]) -> tuple[int, str, str];
def get_remote_url(remote_name: str) -> str;
def get_framework_version_from_text(text: str) -> str | None;
def parse_semver(version_str: str) -> tuple[int, int, int];

"""Use UTF-8 for piped output even on legacy-console hosts."""
def _force_utf8_output -> None;

def main -> int;

with entry:__main__ {
    sys.exit(main());
}
