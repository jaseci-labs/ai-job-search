"""Supply-chain guards for the template's riskiest surfaces.

Run from anywhere: neojac run jobsearch -- security_guards

This repo ships pre-approved Claude Code permissions and CLI code that every
fork user executes. These guards make the dangerous changes LOUD, not
impossible: a PR that intentionally needs one of them must update the
allowlists in this file in the same diff, so the change is explicit and
reviewable rather than buried.

Checks:
1. .claude/settings.json — every permissions.allow entry must be in the exact
   allowlist below. Catches permission widening (e.g. Bash(*), Bash(curl:*)),
   which would auto-approve commands on every fork. The same file's `hooks`
   key is held to an allowlist too: a hook runs automatically when its event
   fires, with no prompt, so it is strictly more dangerous than a pre-approved
   permission. No other top-level key, and no `permissions` key beyond allow,
   ask and deny, may appear: `env`, `apiKeyHelper`, a `statusLine` command or
   `permissions.defaultMode` would run code or switch prompts off behind the
   lists this guard reads.
2. .gitignore — the personal-data ignore rules must all still be present,
   and no un-allowlisted negation (!pattern) may re-include them. Catches
   weakening that would make future users silently commit their tracker,
   profile exports, or application archives. Lines are read as git reads
   them (leading whitespace is part of the pattern), and every .gitignore in
   a subdirectory, which outranks the root file, is checked for negations.
3. .agents/**/package.json — no npm/bun lifecycle scripts (preinstall,
   install, postinstall, preprepare, prepare, postprepare, prepack), no
   trustedDependencies, no workspaces, and no bunfig.toml or .npmrc beside
   the manifest. Catches code execution smuggled into `bun install`, and a
   registry swap.
4. Skill and command frontmatter — every `allowed-tools` entry in
   .claude/skills/*/SKILL.md, .agents/skills/*/SKILL.md and
   .claude/commands/*.md must be in ALLOWED_SKILL_TOOLS (a portal skill may
   instead grant exactly its own CLI). Claude Code pre-approves these for the
   turn that invokes the skill, with no prompt, regardless of workspace trust,
   so the frontmatter is a second permission allowlist. Catches bare Bash and
   glob grants. The same files may carry no frontmatter `hooks` and no
   !`command` dynamic-context line: both run a command when the skill or
   command loads, before any prompt. The settings.json `ask` and `deny` lists
   are also required to keep every rule in REQUIRED_ASK_RULES /
   REQUIRED_DENY_RULES.
5. Agent definitions — every .claude/agents/*.md must declare `tools:` (a
   missing key means every tool) and each entry must be in
   ALLOWED_AGENT_TOOLS, which has no Edit, Write, NotebookEdit or Agent: the
   shipped agents read untrusted postings. `tools:` is tool-name granularity
   (a `Bash(pattern)` entry resolves to plain Bash), so a patterned entry is
   rejected as misleading; settings.json's allow list is what scopes Bash. A
   `permissionMode` must be one that still prompts (ALLOWED_AGENT_PERMISSION_MODES),
   and `hooks` and `mcpServers` are refused.

Stdlib only. Exit 0 on success, 1 with a failure list otherwise.
"""

import builtins;

import json;

import os;

import re;

import subprocess;

import sys;

import from pathlib { Path }

glob ROOT: any;

glob errors: builtins.list[builtins.str];

glob ALLOWED_PERMISSIONS: any;

glob REQUIRED_ASK_RULES: any;

glob REQUIRED_DENY_RULES: any;

glob REQUIRED_IGNORE_RULES: any;

glob ALLOWED_IGNORE_NEGATIONS: any;

glob LOCAL_NEGATIONS_FILE: any;

glob UPSTREAM_REPO: any;

glob ALLOWED_HOOKS: builtins.set[builtins.str];

glob ALLOWED_SETTINGS_KEYS: any;

glob ALLOWED_PERMISSIONS_KEYS: any;

glob FORBIDDEN_SCRIPTS: any;

glob FORBIDDEN_MANIFEST_KEYS: any;

glob INSTALL_CONFIG_FILES: any;

glob ALLOWED_SKILL_TOOLS: any;

glob ALLOWED_AGENT_TOOLS: any;

glob ALLOWED_AGENT_PERMISSION_MODES: any;

glob DYNAMIC_CONTEXT: any;

glob _FRONTMATTER_KEY: any;

glob _REQUIRED_IGNORE_PATTERNS: any;

with entry {
    ROOT = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent);
    errors = [];
    ALLOWED_PERMISSIONS = {
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
    };
    REQUIRED_ASK_RULES = [
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
    ];
    REQUIRED_DENY_RULES = [
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
    ];
    REQUIRED_IGNORE_RULES = [
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
    ];
    ALLOWED_IGNORE_NEGATIONS = {
        "!cover_letters/OpenFonts/fonts/**",
        "!cv/main_example.tex",
        "!cover_letters/cover_example.tex",
        "!documents/**/.gitkeep",
    };
    LOCAL_NEGATIONS_FILE = ROOT / ".github" / "security-guards-local.txt";
    UPSTREAM_REPO = "ai-job-search-dev/ai-job-search";
    ALLOWED_HOOKS = set[any]();
    ALLOWED_SETTINGS_KEYS = {"permissions", "hooks"};
    ALLOWED_PERMISSIONS_KEYS = {"allow", "ask", "deny"};
    FORBIDDEN_SCRIPTS = {
        "preinstall",
        "install",
        "postinstall",
        "preprepare",
        "prepare",
        "postprepare",
        "prepack",
    };
    FORBIDDEN_MANIFEST_KEYS = {"trustedDependencies", "workspaces"};
    INSTALL_CONFIG_FILES = ("bunfig.toml", ".npmrc");
    ALLOWED_SKILL_TOOLS = {
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
    };
    ALLOWED_AGENT_TOOLS = {"Read", "Glob", "Grep", "WebFetch", "WebSearch", "Bash"};
    ALLOWED_AGENT_PERMISSION_MODES = {"default", "manual", "plan"};
    DYNAMIC_CONTEXT = re.compile("!`[^`\\n]+`");
}

"""Frontmatter key spelling-insensitive: permissionMode, permission-mode, ..."""
def _key(name: builtins.str) -> builtins.str;

with entry {
    _FRONTMATTER_KEY = re.compile("^([A-Za-z0-9_-]+):\\s*(.*)$");
}

"""Parse the YAML-ish frontmatter the repo's skills use, stdlib only.

    Returns a dict, or None when the file has no frontmatter. Handles
    `key: value`, folded/literal scalars (`key: >` / `key: |` followed by
    indented lines), and `key:` followed by `- item` lines. Indented lines
    never start a key, so a folded description mentioning "Bash" cannot be
    mistaken for a grant. Anything fancier than that is not used here, and
    an unrecognised shape surfaces as a missing key rather than a crash.
    """
def _frontmatter(text: builtins.str) -> any;

"""Split an `allowed-tools` value into entries (string or list form)."""
def _tool_entries(value) -> builtins.list;

"""The two spellings of 'this portal skill may run its own CLI'."""
def _own_cli_grant(path: Path) -> builtins.set;

def check_skill_tool_grants -> None;

"""Yield "<Event>:<command>" for every command a hook event would run.

    Fails closed: any shape this does not recognise yields a marker that cannot
    be in the allowlist, so an unfamiliar hook layout is rejected rather than
    silently skipped.
    """
def _hook_commands(event: builtins.str, entries: builtins.object) -> Generator[any, any, any];

def check_permissions -> None;

"""The patterns in a .gitignore, read the way git reads them.

    git drops only unescaped trailing whitespace; leading whitespace is part of
    the pattern. The guard used to strip both ends, so ` salary_data.json`
    satisfied the required-rule check while git had stopped ignoring the file
    (it now matched only a name beginning with a space).
    """
def _gitignore_lines(path: Path) -> builtins.list[builtins.str];

"""Every .gitignore below the root, skipping .git and installed dependencies."""
def _other_gitignores -> Generator[any, any, any];

"""A .gitignore pattern with the spellings git treats as the same rule folded.

    A leading ``/`` only anchors the pattern to the .gitignore's directory, and the
    root ``.gitignore`` is that directory, so ``/salary_data.json`` and
    ``salary_data.json`` are the same rule for a file at the repo root.
    """
def _normalized_pattern(pattern: builtins.str) -> builtins.str;

with entry {
    _REQUIRED_IGNORE_PATTERNS = {
        _normalized_pattern(rule)
        for rule in REQUIRED_IGNORE_RULES
        if not rule.startswith("!")
    };
}

"""Negations a fork lists in .github/security-guards-local.txt (empty if absent)."""
def load_local_negations -> builtins.set[builtins.str];

"""The local-negations file must never exist on the upstream template itself."""
def check_local_negations_absent_upstream -> None;

def check_gitignore -> None;

def check_package_manifests -> None;

"""Fail on any tracked path with a ``node_modules`` component.

    ``.gitignore``'s old ``node_modules/`` rule matched directories only, so a
    symlink or plain file named ``node_modules`` (a contributor's local symlink
    to an absolute path, #623) was committed, broke ``bun install`` in CI with a
    dangling link, and checked out as a text file on Windows. The rule now has
    no trailing slash; this check catches what the rule cannot, such as a copy
    force-added or inherited from before the rule changed. Skipped quietly when
    the tree is not a git checkout (the guard also runs from a bare copy).
    """
def check_tracked_node_modules -> None;

def check_agent_tool_grants -> None;

def main -> builtins.int;

with entry:__main__ {
    sys.exit(main());
}
