"""Supply-chain guards for the template's riskiest surfaces.

Run from anywhere: neojac run jobsearch -- security_guards

The repo ships pre-approved Claude Code permissions and CLI code that every fork runs. A PR
that needs to widen one of them must update the allowlists below in the same diff. Checks:
1. .claude/settings.json: allow entries, hooks, and top-level and permissions keys are held
   to allowlists; the required ask and deny rules must all be present.
2. .gitignore: every personal-data rule is present, read as git reads it, and no negation
   outside the allowlist appears in the root file or in a subdirectory's.
3. .agents/**/package.json: no lifecycle scripts, trustedDependencies or workspaces, and no
   bunfig.toml or .npmrc beside the manifest; no tracked node_modules path.
4. Skill and command frontmatter: allowed-tools entries are in ALLOWED_SKILL_TOOLS (a portal
   skill may grant only its own CLI), with no `hooks` and no !`command` line.
5. .claude/agents/*.md: `tools:` is declared and drawn from ALLOWED_AGENT_TOOLS, the
   permissionMode still prompts, and `hooks` and `mcpServers` are refused.

Stdlib only. Exit 0 on success, 1 with a failure list otherwise.
"""

import json;
import os;
import re;
import subprocess;
import sys;
import from pathlib { Path }

glob ROOT: Path = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent),
     errors: list[str] = [],
     ALLOWED_PERMISSIONS: set[str] = {
         "Skill(job-application-assistant)",
         "Bash(neojac run jobsearch -- salary_lookup:*)",
         "Bash(neojac run jobsearch -- rank_state:*)",
         "Bash(neojac run jobsearch -- job_key:*)",
         "Bash(neojac run jobsearch -- scrape_state:*)",
         "Bash(neojac run jobsearch -- verify_pdf:*)",
         "Bash(neojac run jobsearch -- verify_layout:*)",
         "Bash(neojac run jobsearch -- robots_check:*)",
         "Bash(neojac run jobsearch -- fetch_page:*)",
         "Bash(neojac run jobsearch -- posting_guard:*)",
         "Bash(neojac run jobsearch -- html_report:*)",
     },
     REQUIRED_ASK_RULES: list[str] = [
         "Edit(.claude/settings.json)",
         "Edit(.claude/settings.local.json)",
         "Edit(.claude/skills/*/SKILL.md)",
         "Edit(.claude/commands/*.md)",
         "Edit(.claude/agents/**)",
         "Edit(.github/**)",
         "Edit(tools/security_guards.jac)",
         "Edit(tools/**)",
         "Edit(.agents/**)",
         "Edit(salary_lookup.jac)",
         "Bash(git push:*)",
     ],
     REQUIRED_DENY_RULES: list[str] = [
         "Read(.env)",
         "Read(.env.*)",
         "Read(~/.ssh/**)",
         "Read(~/.aws/**)",
         "Read(~/.gnupg/**)",
         "Bash(curl -d:*)",
         "Bash(curl --data:*)",
         "Bash(curl -F:*)",
         "Bash(curl --form:*)",
         "Bash(curl -T:*)",
         "Bash(curl --upload-file:*)",
         "Bash(curl -X POST:*)",
         "Bash(curl -X PUT:*)",
         "Bash(curl -XPOST:*)",
         "Bash(curl --request POST:*)",
         "Bash(wget --post-data:*)",
         "Bash(wget --post-file:*)",
         "Bash(wget --method=POST:*)",
         "Bash(scp:*)",
         "Bash(sftp:*)",
         "Bash(ssh:*)",
         "Bash(nc:*)",
         "Bash(ncat:*)",
         "Bash(netcat:*)",
     ],
     REQUIRED_IGNORE_RULES: list[str] = [
         "salary_data.json",
         "**/job_scraper/seen_jobs.json",
         "**/job_scraper/seen_jobs.json.bak-*",
         "**/job_scraper/notion_sync.json",
         "**/job_scraper/*.md",
         "*_BehavioralReport.pdf",
         "linkedin_Profile.pdf",
         "cv/main_*.*",
         "!cv/main_example.tex",
         "cv/*.txt",
         "cover_letters/cover_*.*",
         "cover_letters/Cover_*.*",
         "documents/cv/**",
         "documents/linkedin/**",
         "documents/diplomas/**",
         "documents/references/**",
         "documents/projects/**",
         "documents/applications/**",
         "documents/postings/**",
         "documents/interview/**",
         "job_search_tracker.csv",
         "gmail_sync/",
         "reports/",
         "upskill/*.md",
         "**/upskill/report-*.md",
         ".env",
         ".env.*",
         "company_research/*.json",
         ".claude/settings.local.json",
     ],
     ALLOWED_IGNORE_NEGATIONS: set[str] = {
         "!cover_letters/OpenFonts/fonts/**",
         "!cv/main_example.tex",
         "!cover_letters/cover_example.tex",
         "!documents/**/.gitkeep",
     },
     LOCAL_NEGATIONS_FILE: Path = ROOT / ".github" / "security-guards-local.txt",
     UPSTREAM_REPO: str = "ai-job-search-dev/ai-job-search",
     ALLOWED_HOOKS: set[str] = set(),
     ALLOWED_SETTINGS_KEYS: set[str] = {"permissions", "hooks"},
     ALLOWED_PERMISSIONS_KEYS: set[str] = {"allow", "ask", "deny"},
     FORBIDDEN_SCRIPTS: set[str] = {
         "preinstall",
         "install",
         "postinstall",
         "preprepare",
         "prepare",
         "postprepare",
         "prepack",
     },
     FORBIDDEN_MANIFEST_KEYS: dict[str, str] = {
         "trustedDependencies": "it re-enables dependency lifecycle scripts that bun blocks by default",
         "workspaces": "each workspace package brings its own lifecycle scripts, which this check never reads, into `bun install`",
     },
     INSTALL_CONFIG_FILES: tuple[str, ...] = ("bunfig.toml", ".npmrc"),
     ALLOWED_SKILL_TOOLS: set[str] = {
         "Read",
         "Glob",
         "Grep",
         "WebFetch",
         "WebSearch",
         "Edit",
         "Write",
         "AskUserQuestion",
         "Agent",
         "Bash(bun --version)",
         "Bash(neojac run jobsearch -- job_key:*)",
         "Bash(neojac run jobsearch -- scrape_state:*)",
     },
     ALLOWED_AGENT_TOOLS: set[str] = {"Read", "Glob", "Grep", "WebFetch", "WebSearch", "Bash"},
     ALLOWED_AGENT_PERMISSION_MODES: set[str] = {"default", "manual", "plan"},
     DYNAMIC_CONTEXT: any = re.compile("!`[^`\\n]+`"),
     _FRONTMATTER_KEY: any = re.compile("^([A-Za-z0-9_-]+):\\s*(.*)$");

"""A frontmatter key with its spelling folded: permissionMode, permission-mode, ..."""
def _key(name: str) -> str;

"""The frontmatter as a dict, or None when the file has none.

Reads `key: value`, folded and literal scalars, and `key:` followed by `- item` lines.
Indented lines never start a key.
"""
def _frontmatter(text: str) -> dict[str, any] | None;

"""A frontmatter file's text, or None after reporting it unreadable."""
def _read(path: Path, rel: str) -> str | None;

"""The entries of an `allowed-tools` or `tools` value, in string or list form."""
def _tool_entries(value: any) -> list[str];

"""The two spellings with which the portal skill at `rel` may grant its own CLI."""
def _own_cli_grant(rel: str) -> set[str];

def check_skill_tool_grants -> None;

"""'<Event>:<command>' for each command of a hook event; an unrecognised shape gives a marker no allowlist holds."""
def _hook_commands(event: str, entries: any) -> list[str];

def _is_str_list(value: any) -> bool;

def check_permissions -> None;

"""The patterns of a .gitignore as git reads them: only unescaped trailing whitespace is dropped."""
def _gitignore_lines(path: Path) -> list[str];

"""Every .gitignore below the root, outside .git and node_modules."""
def _other_gitignores -> list[Path];

"""A .gitignore pattern without the leading `./` and `/` that git reads as the same root rule."""
def _normalized_pattern(pattern: str) -> str;

"""Negations a fork lists in .github/security-guards-local.txt (empty if absent)."""
def load_local_negations -> set[str];

"""The local-negations file must never exist on the upstream template itself."""
def check_local_negations_absent_upstream -> None;

def check_gitignore -> None;

def check_package_manifests -> None;

"""Fail on any tracked path with a `node_modules` component; skipped outside a git checkout."""
def check_tracked_node_modules -> None;

def check_agent_tool_grants -> None;

def main -> int;

with entry:__main__ {
    sys.exit(main());
}
