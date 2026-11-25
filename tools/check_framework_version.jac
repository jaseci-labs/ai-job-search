"""CI check: every framework file carries a 'framework_version' frontmatter key,
and none is modified in git without that version being bumped.

Framework files are the markdown files of .claude/skills/job-application-assistant/ and AGENTS.md.
"""

import os;
import re;
import subprocess;
import sys;
import from pathlib { Path }

glob ROOT: Path = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent),
     SKILL_DIR: Path = ROOT / ".claude/skills/job-application-assistant",
     FRAMEWORK_FILES: list[Path] = sorted(SKILL_DIR.glob("*.md")) + [
         p
         for p in [ROOT / "AGENTS.md"]
         if p.exists()
     ],
     VERSION_LINE: str = "^framework_version\\s*:";

def run_git(args: list[str]) -> tuple[int, str, str];

"""The ref to diff against: the pull request's base, the previous commit in CI, else HEAD."""
def get_base_commit -> str | None;

def parse_frontmatter(path: Path) -> dict[str, str];
def parse_frontmatter_text(text: str) -> dict[str, str];

"""Whether the file changed since base_commit without its framework_version changing."""
def has_non_trivial_changes(file_path: Path, base_commit: str) -> bool;

def main -> int;

with entry:__main__ {
    sys.exit(main());
}
