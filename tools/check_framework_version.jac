"""CI check: ensure that modified framework files have updated version markers.

Fails if any markdown file under .claude/skills/job-application-assistant/ is
modified in git without a change/bump to its 'framework_version' frontmatter key.
Also ensures all framework files have a valid 'framework_version' frontmatter key.
"""

import operator;

import from __future__ { annotations }

import os;

import re;

import subprocess;

import sys;

import from pathlib { Path }

glob ROOT: any;

glob SKILL_DIR: any;

glob FRAMEWORK_FILES: any;

glob root_agents: any;

with entry {
    ROOT = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent);
    SKILL_DIR = ROOT / ".claude/skills/job-application-assistant";
    FRAMEWORK_FILES = sorted(SKILL_DIR.glob("*.md"));
    root_agents = ROOT / "AGENTS.md";
    if root_agents.exists() {
        FRAMEWORK_FILES.append(root_agents);
    }
}

def run_git(args: list[str]) -> tuple[int, str, str];

def get_base_commit -> str | None;

def parse_frontmatter(path: Path) -> dict;

def parse_frontmatter_text(text: str) -> dict;

def has_non_trivial_changes(file_path: Path, base_commit: str) -> bool;

def main -> int;

with entry:__main__ {
    sys.exit(main());
}
