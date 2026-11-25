"""Lint the repo's skill, command, and settings files.

Run from anywhere: neojac run jobsearch -- lint_skills

Checks:
- Every SKILL.md (.claude/skills/*, .agents/skills/*) has YAML frontmatter that
  parses, with non-empty `name` and `description` keys
- `allowed-tools` entries of the form `Bash(bun run <path> *)` point at files
  that exist (skill paths resolve relative to the repo root and to .agents/)
- Every .claude/commands/*.md starts with a `# /<name>` title
- .claude/settings.json is valid JSON with a permissions.allow list

Exit code 0 on success, 1 with a failure list otherwise.
"""

import os;

import builtins;

import json;

import re;

import sys;

import from pathlib { Path }

glob yaml: any;

glob ROOT: any;

glob errors: builtins.list[builtins.str];

with entry {
    try {
        import yaml;
    } except ImportError {
        sys.exit("lint_skills.jac requires PyYAML: neojac install");
    }

    ROOT = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent);
    errors = [];
}

def rel(path: Path) -> builtins.str;

def check_skill(path: Path) -> None;

def check_command(path: Path) -> None;

def check_settings -> None;

def main -> builtins.int;

with entry:__main__ {
    sys.exit(main());
}
