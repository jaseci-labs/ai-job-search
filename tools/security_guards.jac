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

import json, os, re, subprocess, sys;
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
def _key(name: str) -> str {
    return name.lower().replace("-", "").replace("_", "");
}

"""The frontmatter as a dict, or None when the file has none.

Reads `key: value`, folded and literal scalars, and `key:` followed by `- item` lines.
Indented lines never start a key.
"""
def _frontmatter(text: str) -> dict[str, any] | None {
    text = text.lstrip("﻿");
    lines: list[str] = text.splitlines();
    ends: list[int] = [i for i in range(1, len(lines)) if lines[i].strip() == "---"];
    if not text.startswith("---") or not ends {
        return None;
    }
    data: dict[str, any] = {};
    key: str | None = None;
    for raw in lines[1:ends[0]] {
        found: any = _FRONTMATTER_KEY.match(raw);
        if raw[:1] in (" ", "\t") {
            item: str = raw.strip();
            if key is None {
                continue;
            }
            if item.startswith("- ") {
                if not isinstance(data[key], list) {
                    data[key] = [];
                }
                data[key].append(item[2:].strip());
            } elif isinstance(data[key], str) {
                data[key] = (data[key] + " " + item).strip();
            }
        } elif found {
            key = found.group(1);
            value: str = found.group(2).strip();
            data[key] = "" if value in (">", "|", ">-", "|-") else value;
        } else {
            key = None;
        }
    }
    return data;
}

"""A frontmatter file's text, or None after reporting it unreadable."""
def _read(path: Path, rel: str) -> str | None {
    try {
        return path.read_text(encoding="utf-8");
    } except (OSError, UnicodeDecodeError) as exc {
        errors.append(f"{rel}: unreadable (must be UTF-8): {exc}");
        return None;
    }
}

"""The entries of an `allowed-tools` or `tools` value, in string or list form."""
def _tool_entries(value: any) -> list[str] {
    if isinstance(value, list) {
        return [str(item).strip() for item in value if str(item).strip()];
    }
    if not isinstance(value, str) {
        return [];
    }
    value = value.strip();
    if value.startswith("[") and value.endswith("]") {
        value = value[1:-1];
    }
    entries: list[str] = [""];
    depth: int = 0;
    for char in value {
        if char == "(" {
            depth += 1;
        } elif char == ")" {
            depth = max(depth - 1, 0);
        }
        if char == "," and depth == 0 {
            entries.append("");
        } else {
            entries[-1] += char;
        }
    }
    return [item.strip() for item in entries if item.strip()];
}

"""The two spellings with which the portal skill at `rel` may grant its own CLI."""
def _own_cli_grant(rel: str) -> set[str] {
    parts: list[str] = rel.split("/");
    if len(parts) == 4 and parts[:2] == [".agents", "skills"] and parts[3] == "SKILL.md" {
        cli: str = f"bun run .agents/skills/{parts[2]}/cli/src/cli.ts";
        return {f"Bash({cli} *)", f"Bash({cli}:*)"};
    }
    return set();
}

def check_skill_tool_grants -> None {
    skills: list[Path] = sorted(ROOT.glob(".claude/skills/*/SKILL.md"))
        + sorted(ROOT.glob(".agents/skills/*/SKILL.md"));
    commands: list[Path] = sorted((ROOT / ".claude" / "commands").rglob("*.md"));
    for path in skills + commands {
        rel: str = path.relative_to(ROOT).as_posix();
        text: str | None = _read(path, rel);
        if text is None {
            continue;
        }
        for found in DYNAMIC_CONTEXT.finditer(text) {
            errors.append(
                f"{rel}: dynamic-context line {found.group(0)!r}. Claude Code runs a !`command` when the skill or command loads and splices its output into the prompt, with no permission check, so this is a pre-approved shell command. Move it into a step the model runs, where settings.json decides.",
            );
        }
        data: dict[str, any] | None = _frontmatter(text);
        if data is None {
            if path not in commands {
                errors.append(f"{rel}: missing or unterminated frontmatter (expected --- ... ---)");
            }
            continue;
        }
        if "hooks" in {_key(k) for k in data} {
            errors.append(
                f"{rel}: frontmatter `hooks`. A skill or command hook runs its command with no prompt whenever its event fires while the skill is active; the template ships no hooks (SECURITY.md), and settings.json hooks are held to ALLOWED_HOOKS.",
            );
        }
        permitted: set[str] = _own_cli_grant(rel) or ALLOWED_SKILL_TOOLS;
        for item in _tool_entries(data.get("allowed-tools", "")) {
            if item in permitted {
                continue;
            }
            if "*" in item and not (item.endswith((" *)", ":*)")) and "*" not in item[:-2]) {
                errors.append(
                    f"{rel}: allowed-tools entry uses a wildcard inside the pattern: {item!r}. A glob here pre-approves whatever lands at that path, including code added later; name the exact command instead.",
                );
            } else {
                errors.append(
                    f"{rel}: allowed-tools entry not in the reviewed allowlist: {item!r}. Claude Code pre-approves allowed-tools for the turn that invokes the skill, with no prompt and regardless of workspace trust, so this line is a permission allowlist like settings.json. Bare Bash means any command. If the grant is intentional, add it to ALLOWED_SKILL_TOOLS in tools/security_guards.jac in the same PR; a portal skill may grant only its own .agents/skills/<name>/cli/src/cli.ts.",
                );
            }
        }
    }
}

"""'<Event>:<command>' for each command of a hook event; an unrecognised shape gives a marker no allowlist holds."""
def _hook_commands(event: str, entries: any) -> list[str] {
    unrecognised: str = f"{event}:<unrecognised hook shape>";
    if not isinstance(entries, list) {
        return [unrecognised];
    }
    commands: list[str] = [];
    for item in entries {
        inner: any = item.get("hooks") if isinstance(item, dict) else None;
        if not isinstance(inner, list) {
            commands.append(unrecognised);
            continue;
        }
        for hook in inner {
            command: any = hook.get("command") if isinstance(hook, dict) else None;
            commands.append(f"{event}:{command}" if isinstance(command, str) else unrecognised);
        }
    }
    return commands;
}

def _is_str_list(value: any) -> bool {
    return isinstance(value, list) and all([isinstance(item, str) for item in value]);
}

def check_permissions -> None {
    try {
        data: any = json.loads((ROOT / ".claude" / "settings.json").read_text(encoding="utf-8"));
    } except (OSError, json.JSONDecodeError) as exc {
        errors.append(f".claude/settings.json: unreadable or invalid JSON: {exc}");
        return;
    }
    if not isinstance(data, dict) {
        errors.append(".claude/settings.json: top-level JSON value must be an object");
        return;
    }
    for key in sorted([k for k in data if k not in ALLOWED_SETTINGS_KEYS]) {
        errors.append(
            f".claude/settings.json: top-level setting not in the reviewed allowlist: {key!r}. Only `permissions` and `hooks` are checked here; any other key (env, apiKeyHelper, statusLine, enableAllProjectMcpServers, ...) can run a program or change what every pre-approved tool sees, with no prompt, on every fork. If the key is intentional, add it to ALLOWED_SETTINGS_KEYS in tools/security_guards.jac in the same PR and extend the guard to check its value.",
        );
    }
    hooks: any = data.get("hooks", {});
    if hooks and not isinstance(hooks, dict) {
        errors.append(".claude/settings.json: hooks must be an object");
    } elif hooks {
        for (event, entries) in hooks.items() {
            for command in _hook_commands(str(event), entries) {
                if command not in ALLOWED_HOOKS {
                    errors.append(
                        f".claude/settings.json: hook not in the reviewed allowlist: {command!r}. A hook runs automatically when its event fires - it is never gated by the permissions prompt, so it executes on every fork without the user agreeing to anything. If this hook is intentional, add it to ALLOWED_HOOKS in tools/security_guards.jac in the same PR so the addition is explicit and reviewable.",
                    );
                }
            }
        }
    }
    permissions: any = data.get("permissions", {});
    if not isinstance(permissions, dict) {
        errors.append(".claude/settings.json: permissions must be an object");
        return;
    }
    for key in sorted([k for k in permissions if k not in ALLOWED_PERMISSIONS_KEYS]) {
        errors.append(
            f".claude/settings.json: permissions setting not in the reviewed allowlist: {key!r}. `defaultMode: bypassPermissions` turns every prompt off and `additionalDirectories` widens what the rules scope, so the allow, ask and deny lists are only as strong as the keys beside them. If the key is intentional, add it to ALLOWED_PERMISSIONS_KEYS in tools/security_guards.jac in the same PR and extend the guard to check its value.",
        );
    }
    allow: any = permissions.get("allow", []);
    if not _is_str_list(allow) {
        errors.append(".claude/settings.json: permissions.allow must be a list of strings");
        return;
    }
    for item in allow {
        if item not in ALLOWED_PERMISSIONS {
            errors.append(
                f".claude/settings.json: permission not in the reviewed allowlist: {item!r}. Pre-approved permissions run without prompting on every fork. If this entry is intentional, add it to ALLOWED_PERMISSIONS in tools/security_guards.jac in the same PR so the widening is explicit and reviewable.",
            );
        }
    }
    for item in [p for p in ALLOWED_PERMISSIONS if p not in allow] {
        print(f"note: allowlisted permission not present in settings.json: {item!r}");
    }
    for (key, required, effect) in (
        ("ask", REQUIRED_ASK_RULES, "an ask rule forces a prompt even over a skill grant"),
        ("deny", REQUIRED_DENY_RULES, "a deny rule blocks in every mode, bypass included"),
    ) {
        rules: any = permissions.get(key, []);
        if not _is_str_list(rules) {
            errors.append(f".claude/settings.json: permissions.{key} must be a list of strings");
            continue;
        }
        for rule in required {
            if rule not in rules {
                errors.append(
                    f".claude/settings.json: required {key} rule missing: {rule!r}. Removing it silently re-opens what it closed ({effect}). If the change is intentional, update REQUIRED_{key.upper()}_RULES in tools/security_guards.jac in the same PR so the widening is explicit and reviewable.",
                );
            }
        }
    }
}

"""The patterns of a .gitignore as git reads them: only unescaped trailing whitespace is dropped."""
def _gitignore_lines(path: Path) -> list[str] {
    return [
        re.sub("(?<!\\\\)\\s+$", "", line)
        for line in path.read_text(encoding="utf-8").splitlines()
    ];
}

"""Every .gitignore below the root, outside .git and node_modules."""
def _other_gitignores -> list[Path] {
    found: list[Path] = [];
    for (dirpath, dirnames, filenames) in os.walk(ROOT) {
        dirnames[:] = sorted([d for d in dirnames if d not in (".git", "node_modules")]);
        if ".gitignore" in filenames and Path(dirpath) != ROOT {
            found.append(Path(dirpath) / ".gitignore");
        }
    }
    return found;
}

"""A .gitignore pattern without the leading `./` and `/` that git reads as the same root rule."""
def _normalized_pattern(pattern: str) -> str {
    return re.sub("^(\\./)*/*", "", pattern.strip());
}

"""Negations a fork lists in .github/security-guards-local.txt (empty if absent)."""
def load_local_negations -> set[str] {
    extra: set[str] = set();
    if not LOCAL_NEGATIONS_FILE.is_file() {
        return extra;
    }
    try {
        raw: list[str] = LOCAL_NEGATIONS_FILE.read_text(encoding="utf-8").splitlines();
    } except OSError as exc {
        errors.append(f".github/security-guards-local.txt: unreadable: {exc}");
        return extra;
    }
    required: set[str] = {
        _normalized_pattern(rule)
        for rule in REQUIRED_IGNORE_RULES
        if not rule.startswith("!")
    };
    for (number, line) in enumerate([text.strip() for text in raw], 1) {
        if not line or line.startswith("#") {
            continue;
        }
        if not line.startswith("!") {
            errors.append(
                f".github/security-guards-local.txt:{number}: {line!r} is not a negation. The file may only list `!pattern` lines that extend the .gitignore negation allowlist.",
            );
        } elif _normalized_pattern(line[1:]) in required {
            errors.append(
                f".github/security-guards-local.txt:{number}: {line!r} negates a required personal-data ignore rule (REQUIRED_IGNORE_RULES). A fork may re-include its own tracked paths, never the rule that keeps personal data out of git.",
            );
        } else {
            extra.add(line);
        }
    }
    return extra;
}

"""The local-negations file must never exist on the upstream template itself."""
def check_local_negations_absent_upstream -> None {
    if os.environ.get("GITHUB_REPOSITORY") == UPSTREAM_REPO and LOCAL_NEGATIONS_FILE.exists() {
        errors.append(
            ".github/security-guards-local.txt must not exist on the upstream template: it is a fork-only extension point. Remove it from this PR.",
        );
    }
}

def check_gitignore -> None {
    try {
        lines: list[str] = _gitignore_lines(ROOT / ".gitignore");
    } except OSError as exc {
        errors.append(f".gitignore: unreadable: {exc}");
        return;
    }
    for rule in REQUIRED_IGNORE_RULES {
        if rule not in lines {
            errors.append(
                f".gitignore: required personal-data rule missing: {rule!r}. These rules keep fork users from committing personal data. If the rule moved or was renamed intentionally, update REQUIRED_IGNORE_RULES in tools/security_guards.jac in the same PR.",
            );
        }
    }
    check_local_negations_absent_upstream();
    allowed_negations: set[str] = ALLOWED_IGNORE_NEGATIONS | load_local_negations();
    for line in lines {
        if line.startswith("!") and line not in allowed_negations {
            errors.append(
                f".gitignore: negation rule not in the reviewed allowlist: {line!r}. A negation re-includes a path an earlier rule excluded and can silently re-expose personal data (a required ignore rule stays present but stops taking effect). If this negation is intentional, add it to ALLOWED_IGNORE_NEGATIONS in tools/security_guards.jac in the same PR (on a fork, list it in .github/security-guards-local.txt instead).",
            );
        }
    }
    for sub in _other_gitignores() {
        rel: str = sub.relative_to(ROOT).as_posix();
        try {
            sub_lines: list[str] = _gitignore_lines(sub);
        } except OSError as exc {
            errors.append(f"{rel}: unreadable: {exc}");
            continue;
        }
        for line in sub_lines {
            scoped: str = f"{rel}:{line}";
            if line.startswith("!") and scoped not in ALLOWED_IGNORE_NEGATIONS {
                errors.append(
                    f"{rel}: negation rule not in the reviewed allowlist: {line!r}. A subdirectory .gitignore takes precedence over the root file, so this re-includes paths the root rules exclude. If it is intentional, add {scoped!r} to ALLOWED_IGNORE_NEGATIONS in tools/security_guards.jac in the same PR.",
                );
            }
        }
    }
}

def check_package_manifests -> None {
    for manifest in ROOT.glob(".agents/**/package.json") {
        if "node_modules" in manifest.parts {
            continue;
        }
        relpath: Path = manifest.relative_to(ROOT);
        try {
            data: any = json.loads(manifest.read_text(encoding="utf-8"));
        } except (OSError, json.JSONDecodeError) as exc {
            errors.append(f"{relpath}: unreadable or invalid JSON: {exc}");
            continue;
        }
        if not isinstance(data, dict) {
            errors.append(f"{relpath}: top-level JSON value must be an object");
            continue;
        }
        scripts: any = data.get("scripts", {});
        if not isinstance(scripts, dict) {
            errors.append(f"{relpath}: scripts must be an object");
            continue;
        }
        bad: list[str] = sorted([s for s in scripts if s in FORBIDDEN_SCRIPTS]);
        if bad {
            errors.append(
                f"{relpath}: lifecycle script(s) {bad} are forbidden - they execute arbitrary code during `bun install` on every fork user's machine.",
            );
        }
        for (key, why) in FORBIDDEN_MANIFEST_KEYS.items() {
            if key in data {
                errors.append(f"{relpath}: {key} is forbidden - {why}.");
            }
        }
        for name in INSTALL_CONFIG_FILES {
            config: Path = manifest.parent / name;
            if config.exists() {
                errors.append(
                    f"{config.relative_to(ROOT)}: a {name} beside a portal manifest is forbidden - it reconfigures `bun install` itself (registry, scopes, trusted packages) for every fork user.",
                );
            }
        }
    }
}

"""Fail on any tracked path with a `node_modules` component; skipped outside a git checkout."""
def check_tracked_node_modules -> None {
    try {
        proc: any = subprocess.run(
            ["git", "ls-files", "-z"], cwd=ROOT, capture_output=True, check=False
        );
    } except OSError {
        return;
    }
    if proc.returncode != 0 {
        return;
    }
    for rel in proc.stdout.decode("utf-8", errors="replace").split("\x00") {
        if "node_modules" in rel.split("/") {
            errors.append(
                f"tracked path inside node_modules: {rel!r}. Installed dependencies (or a symlink standing in for them) must never be committed: run `git rm --cached` on it; .gitignore's `node_modules` rule keeps it out.",
            );
        }
    }
}

def check_agent_tool_grants -> None {
    for path in sorted((ROOT / ".claude" / "agents").rglob("*.md")) {
        rel: str = path.relative_to(ROOT).as_posix();
        text: str | None = _read(path, rel);
        if text is None {
            continue;
        }
        data: dict[str, any] | None = _frontmatter(text);
        if data is None {
            errors.append(f"{rel}: missing or unterminated frontmatter (expected --- ... ---)");
            continue;
        }
        keyed: dict[str, any] = {_key(k): v for (k, v) in data.items()};
        mode: any = keyed.get("permissionmode");
        if mode is not None
            and str(mode).strip().strip("'\"") not in ALLOWED_AGENT_PERMISSION_MODES
        {
            errors.append(
                f"{rel}: permissionMode {mode!r}. An agent's mode applies to every call it makes, and this one removes prompts the allowlists here assume; use one of {sorted(ALLOWED_AGENT_PERMISSION_MODES)} or omit the key.",
            );
        }
        for (key, why) in (
            ("hooks", "runs its command with no prompt whenever its event fires inside the agent"),
            ("mcpservers", "connects a server whose tools no allowlist here has reviewed"),
        ) {
            if key in keyed {
                errors.append(f"{rel}: frontmatter `{key}`: an agent-scoped entry {why}.");
            }
        }
        tools: list[str] = _tool_entries(data.get("tools"));
        if not tools {
            errors.append(
                f"{rel}: no `tools:` key - an agent without one gets every tool, including Edit, Write and Bash. Shipped agents read untrusted posting text; declare an explicit list drawn from {sorted(ALLOWED_AGENT_TOOLS)}.",
            );
        }
        for item in tools {
            if item in ALLOWED_AGENT_TOOLS {
                continue;
            }
            if "(" in item {
                errors.append(
                    f"{rel}: tools entry {item!r} looks scoped but is not - an agent's `tools:` list is tool-name granularity (a `Bash(pattern)` entry gives the agent plain Bash). List the bare tool and let settings.json's allow list scope it.",
                );
            } else {
                errors.append(
                    f"{rel}: tools entry not in the reviewed allowlist: {item!r}. Shipped agent definitions read untrusted posting text, so they may not edit or write files or spawn further agents. If the grant is intentional, add it to ALLOWED_AGENT_TOOLS in tools/security_guards.jac in the same PR.",
                );
            }
        }
    }
}

def main -> int {
    check_permissions();
    check_gitignore();
    check_package_manifests();
    check_tracked_node_modules();
    check_skill_tool_grants();
    check_agent_tool_grants();
    if errors {
        print(f"security_guards: {len(errors)} failure(s)");
        for err in errors {
            print(f"  - {err}");
        }
        return 1;
    }
    print(
        "security_guards: OK (permissions allowlist, hooks allowlist, gitignore rules, package manifests, no tracked node_modules, skill/command allowed-tools, load-time commands, agent tools and modes)",
    );
    return 0;
}

with entry:__main__ {
    sys.exit(main());
}
