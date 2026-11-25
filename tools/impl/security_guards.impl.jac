impl _key(name: builtins.str) -> builtins.str {
    return name.lower().replace("-", "").replace("_", "");
}

impl _frontmatter(text: builtins.str) -> any {
    lines: any;
    text = text.lstrip("﻿");
    if not text.startswith("---") {
        return None;
    }
    lines = text.splitlines();
    end: any = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None);
    if end is None {
        return None;
    }
    data: builtins.dict = {};
    key: any = None;
    for raw in lines[1:end] {
        if raw[:1] in (" ", "\t") {
            if key is None {
                continue;
            }
            stripped: any = raw.strip();
            if stripped.startswith("- ") {
                if not isinstance(data[key], `list) {
                    data[key] = [];
                }
                data[key].append(stripped[2:].strip());
            } elif isinstance(data[key], `str) {
                data[key] = (data[key] + " " + stripped).strip();
            }
            continue;
        }
        `match: any = _FRONTMATTER_KEY.match(raw);
        if not `match {
            key = None;
            continue;
        }
        value: any;
        (key, value) = (`match.group(1), `match.group(2).strip());
        data[key] = "" if value in (">", "|", ">-", "|-") else value;
    }
    return data;
}

impl _tool_entries(value) -> builtins.list {
    if isinstance(value, `list) {
        return [`str(item).strip() for item in value if `str(item).strip()];
    }
    if not isinstance(value, `str) {
        return [];
    }
    value = value.strip();
    if value.startswith("[") and value.endswith("]") {
        value = value[1:-1];
    }
    entries: any;
    depth: any;
    current: any;
    (entries, depth, current) = ([], 0, []);
    for char in value {
        if char == "(" {
            depth += 1;
        } elif char == ")" {
            depth = max(depth - 1, 0);
        }
        if char == "," and depth == 0 {
            entries.append("".join(current).strip());
            current = [];
        } else {
            current.append(char);
        }
    }
    entries.append("".join(current).strip());
    return [`entry for `entry in entries if `entry];
}

impl _own_cli_grant(path: Path) -> builtins.set {
    try {
        rel: any = path.relative_to(ROOT).as_posix();
    } except ValueError {
        return set[any]();
    }
    parts: any = rel.split("/");
    if len(parts) == 4 and parts[:2] == [".agents", "skills"] and parts[3] == "SKILL.md" {
        cli: any = f"bun run .agents/skills/{parts[2]}/cli/src/cli.ts";
        return {f"Bash({cli} *)", f"Bash({cli}:*)"};
    }
    return set[any]();
}

impl check_skill_tool_grants -> None {
    skills: any = sorted(ROOT.glob(".claude/skills/*/SKILL.md"))
        + sorted(ROOT.glob(".agents/skills/*/SKILL.md"));
    commands: any = sorted((ROOT / ".claude" / "commands").rglob("*.md"));
    for path in skills + commands {
        rel: any = path.relative_to(ROOT).as_posix();
        try {
            text: any = path.read_text(encoding="utf-8");
        } except (OSError, UnicodeDecodeError) as exc {
            errors.append(f"{rel}: unreadable (must be UTF-8): {exc}");
            continue;
        }
        for `match in DYNAMIC_CONTEXT.finditer(text) {
            errors.append(
                f"{rel}: dynamic-context line {`match.group(0)!r}. Claude Code runs a !`command` when the skill or command loads and splices its output into the prompt, with no permission check, so this is a pre-approved shell command. Move it into a step the model runs, where settings.json decides.",
            );
        }
        data: any = _frontmatter(text);
        if data is not None and "hooks" in {_key(k) for k in data} {
            errors.append(
                f"{rel}: frontmatter `hooks`. A skill or command hook runs its command with no prompt whenever its event fires while the skill is active; the template ships no hooks (SECURITY.md), and settings.json hooks are held to ALLOWED_HOOKS.",
            );
        }
        if data is None {
            if path in commands {
                continue;
            }
            errors.append(f"{rel}: missing or unterminated frontmatter (expected --- ... ---)");
            continue;
        }
        own_cli: any = _own_cli_grant(path);
        permitted: any = own_cli or ALLOWED_SKILL_TOOLS;
        for `entry in _tool_entries(data.get("allowed-tools", "")) {
            if `entry in permitted {
                continue;
            }
            if "*" in `entry and not (`entry.endswith((" *)", ":*)")) and "*" not in `entry[:-2]) {
                errors.append(
                    f"{rel}: allowed-tools entry uses a wildcard inside the pattern: {`entry!r}. A glob here pre-approves whatever lands at that path, including code added later; name the exact command instead.",
                );
                continue;
            }
            errors.append(
                f"{rel}: allowed-tools entry not in the reviewed allowlist: {`entry!r}. Claude Code pre-approves allowed-tools for the turn that invokes the skill, with no prompt and regardless of workspace trust, so this line is a permission allowlist like settings.json. Bare Bash means any command. If the grant is intentional, add it to ALLOWED_SKILL_TOOLS in tools/security_guards.jac in the same PR; a portal skill may grant only its own .agents/skills/<name>/cli/src/cli.ts.",
            );
        }
    }
}

impl _hook_commands(event: builtins.str, entries: builtins.object) -> Generator[any, any, any] {
    unrecognised: any = f"{event}:<unrecognised hook shape>";
    if not isinstance(entries, `list) {
        yield unrecognised;
        return;
    }
    for `entry in entries {
        if not isinstance(`entry, `dict) {
            yield unrecognised;
            continue;
        }
        inner: any = `entry.get("hooks");
        if not isinstance(inner, `list) {
            yield unrecognised;
            continue;
        }
        for hook in inner {
            command: any = hook.get("command") if isinstance(hook, `dict) else None;
            yield f"{event}:{command}" if isinstance(command, `str) else unrecognised;
        }
    }
}

impl check_permissions -> None {
    `entry: any;
    path: any = ROOT / ".claude" / "settings.json";
    try {
        data: any = json.loads(path.read_text(encoding="utf-8"));
    } except (OSError, json.JSONDecodeError) as exc {
        errors.append(f".claude/settings.json: unreadable or invalid JSON: {exc}");
        return;
    }
    if not isinstance(data, `dict) {
        errors.append(".claude/settings.json: top-level JSON value must be an object");
        return;
    }
    key: any;
    for key in sorted(`set(data) - ALLOWED_SETTINGS_KEYS) {
        errors.append(
            f".claude/settings.json: top-level setting not in the reviewed allowlist: {key!r}. Only `permissions` and `hooks` are checked here; any other key (env, apiKeyHelper, statusLine, enableAllProjectMcpServers, ...) can run a program or change what every pre-approved tool sees, with no prompt, on every fork. If the key is intentional, add it to ALLOWED_SETTINGS_KEYS in tools/security_guards.jac in the same PR and extend the guard to check its value.",
        );
    }
    hooks: any = data.get("hooks", {});
    if hooks {
        if not isinstance(hooks, `dict) {
            errors.append(".claude/settings.json: hooks must be an object");
        } else {
            for (event, entries) in hooks.items() {
                for command in _hook_commands(`str(event), entries) {
                    if command not in ALLOWED_HOOKS {
                        errors.append(
                            f".claude/settings.json: hook not in the reviewed allowlist: {command!r}. A hook runs automatically when its event fires - it is never gated by the permissions prompt, so it executes on every fork without the user agreeing to anything. If this hook is intentional, add it to ALLOWED_HOOKS in tools/security_guards.jac in the same PR so the addition is explicit and reviewable.",
                        );
                    }
                }
            }
        }
    }

    permissions: any = data.get("permissions", {});
    if not isinstance(permissions, `dict) {
        errors.append(".claude/settings.json: permissions must be an object");
        return;
    }
    for key in sorted(`set(permissions) - ALLOWED_PERMISSIONS_KEYS) {
        errors.append(
            f".claude/settings.json: permissions setting not in the reviewed allowlist: {key!r}. `defaultMode: bypassPermissions` turns every prompt off and `additionalDirectories` widens what the rules scope, so the allow, ask and deny lists are only as strong as the keys beside them. If the key is intentional, add it to ALLOWED_PERMISSIONS_KEYS in tools/security_guards.jac in the same PR and extend the guard to check its value.",
        );
    }
    allow: any = permissions.get("allow", []);
    if not isinstance(allow, `list) or not all(isinstance(`entry, `str) for `entry in allow) {
        errors.append(".claude/settings.json: permissions.allow must be a list of strings");
        return;
    }
    for `entry in allow {
        if `entry not in ALLOWED_PERMISSIONS {
            errors.append(
                f".claude/settings.json: permission not in the reviewed allowlist: {`entry!r}. Pre-approved permissions run without prompting on every fork. If this entry is intentional, add it to ALLOWED_PERMISSIONS in tools/security_guards.jac in the same PR so the widening is explicit and reviewable.",
            );
        }
    }
    for `entry in ALLOWED_PERMISSIONS - `set(allow) {
        print(f"note: allowlisted permission not present in settings.json: {`entry!r}");
    }

    for (key, required, effect) in (
        ("ask", REQUIRED_ASK_RULES, "an ask rule forces a prompt even over a skill grant"),
        ("deny", REQUIRED_DENY_RULES, "a deny rule blocks in every mode, bypass included"),
    ) {
        rules: any = permissions.get(key, []);
        if not isinstance(rules, `list) or not all(isinstance(`entry, `str) for `entry in rules) {
            errors.append(f".claude/settings.json: permissions.{key} must be a list of strings");
            continue;
        }
        present: any = `set(rules);
        for rule in required {
            if rule not in present {
                errors.append(
                    f".claude/settings.json: required {key} rule missing: {rule!r}. Removing it silently re-opens what it closed ({effect}). If the change is intentional, update REQUIRED_{key.upper()}_RULES in tools/security_guards.jac in the same PR so the widening is explicit and reviewable.",
                );
            }
        }
    }
}

impl _gitignore_lines(path: Path) -> builtins.list[builtins.str] {
    return [
        re.sub("(?<!\\\\)\\s+$", "", line)
        for line in path.read_text(encoding="utf-8").splitlines()
    ];
}

impl _other_gitignores -> Generator[any, any, any] {
    for (dirpath, dirnames, filenames) in os.walk(ROOT) {
        dirnames[:] = sorted(d for d in dirnames if d not in (".git", "node_modules"));
        if ".gitignore" in filenames and Path(dirpath) != ROOT {
            yield Path(dirpath) / ".gitignore";
        }
    }
}

impl _normalized_pattern(pattern: builtins.str) -> builtins.str {
    pattern = pattern.strip();
    while pattern.startswith("./") {
        pattern = pattern[2:];
    }
    return pattern.lstrip("/");
}

impl load_local_negations -> builtins.set[builtins.str] {
    if not LOCAL_NEGATIONS_FILE.is_file() {
        return set[any]();
    }
    try {
        raw: any = LOCAL_NEGATIONS_FILE.read_text(encoding="utf-8").splitlines();
    } except OSError as exc {
        errors.append(f".github/security-guards-local.txt: unreadable: {exc}");
        return set[any]();
    }
    extra: builtins.set[builtins.str] = set[any]();
    line: any;
    for (number, line) in enumerate(raw, 1) {
        line = line.strip();
        if not line or line.startswith("#") {
            continue;
        }
        if not line.startswith("!") {
            errors.append(
                f".github/security-guards-local.txt:{number}: {line!r} is not a negation. The file may only list `!pattern` lines that extend the .gitignore negation allowlist.",
            );
            continue;
        }
        if _normalized_pattern(line[1:]) in _REQUIRED_IGNORE_PATTERNS {
            errors.append(
                f".github/security-guards-local.txt:{number}: {line!r} negates a required personal-data ignore rule (REQUIRED_IGNORE_RULES). A fork may re-include its own tracked paths, never the rule that keeps personal data out of git.",
            );
            continue;
        }
        extra.add(line);
    }
    return extra;
}

impl check_local_negations_absent_upstream -> None {
    if os.environ.get("GITHUB_REPOSITORY") == UPSTREAM_REPO and LOCAL_NEGATIONS_FILE.exists() {
        errors.append(
            ".github/security-guards-local.txt must not exist on the upstream template: it is a fork-only extension point. Remove it from this PR.",
        );
    }
}

impl check_gitignore -> None {
    path: any = ROOT / ".gitignore";
    try {
        lines: any = _gitignore_lines(path);
    } except OSError as exc {
        errors.append(f".gitignore: unreadable: {exc}");
        return;
    }
    rules: any = `set(lines);
    for rule in REQUIRED_IGNORE_RULES {
        if rule not in rules {
            errors.append(
                f".gitignore: required personal-data rule missing: {rule!r}. These rules keep fork users from committing personal data. If the rule moved or was renamed intentionally, update REQUIRED_IGNORE_RULES in tools/security_guards.jac in the same PR.",
            );
        }
    }
    check_local_negations_absent_upstream();
    allowed_negations: any = ALLOWED_IGNORE_NEGATIONS | load_local_negations();
    line: any;
    for line in lines {
        if line.startswith("!") and line not in allowed_negations {
            errors.append(
                f".gitignore: negation rule not in the reviewed allowlist: {line!r}. A negation re-includes a path an earlier rule excluded and can silently re-expose personal data (a required ignore rule stays present but stops taking effect). If this negation is intentional, add it to ALLOWED_IGNORE_NEGATIONS in tools/security_guards.jac in the same PR (on a fork, list it in .github/security-guards-local.txt instead).",
            );
        }
    }
    for sub in _other_gitignores() {
        rel: any = sub.relative_to(ROOT).as_posix();
        try {
            sub_lines: any = _gitignore_lines(sub);
        } except OSError as exc {
            errors.append(f"{rel}: unreadable: {exc}");
            continue;
        }
        for line in sub_lines {
            if line.startswith("!") and f"{rel}:{line}" not in ALLOWED_IGNORE_NEGATIONS {
                errors.append(
                    format(rel, "")
                        + ": negation rule not in the reviewed allowlist: "
                        + format(repr(line), "")
                        + ". A subdirectory .gitignore takes precedence over the root file, so this re-includes paths the root rules exclude. If it is intentional, add "
                        + format(repr(rel + ":" + line), "")
                        + " to ALLOWED_IGNORE_NEGATIONS in tools/security_guards.jac in the same PR.",
                );
            }
        }
    }
}

impl check_package_manifests -> None {
    manifests: any = [
        p
        for p in ROOT.glob(".agents/**/package.json")
        if "node_modules" not in p.parts
    ];
    for manifest in manifests {
        relpath: any = manifest.relative_to(ROOT);
        try {
            data: any = json.loads(manifest.read_text(encoding="utf-8"));
        } except (OSError, json.JSONDecodeError) as exc {
            errors.append(f"{relpath}: unreadable or invalid JSON: {exc}");
            continue;
        }
        if not isinstance(data, `dict) {
            errors.append(f"{relpath}: top-level JSON value must be an object");
            continue;
        }
        scripts: any = data.get("scripts", {});
        if not isinstance(scripts, `dict) {
            errors.append(f"{relpath}: scripts must be an object");
            continue;
        }
        bad: any = FORBIDDEN_SCRIPTS & `set(scripts);
        if bad {
            errors.append(
                f"{relpath}: lifecycle script(s) {sorted(bad)} are forbidden - they execute arbitrary code during `bun install` on every fork user's machine.",
            );
        }
        if "trustedDependencies" in data {
            errors.append(
                f"{relpath}: trustedDependencies is forbidden - it re-enables dependency lifecycle scripts that bun blocks by default.",
            );
        }
        if "workspaces" in data {
            errors.append(
                f"{relpath}: workspaces is forbidden - each workspace package brings its own lifecycle scripts, which this check never reads, into `bun install`.",
            );
        }
        for name in INSTALL_CONFIG_FILES {
            config: any = manifest.parent / name;
            if config.exists() {
                errors.append(
                    f"{config.relative_to(ROOT)}: a {name} beside a portal manifest is forbidden - it reconfigures `bun install` itself (registry, scopes, trusted packages) for every fork user.",
                );
            }
        }
    }
}

impl check_tracked_node_modules -> None {
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
        if rel and "node_modules" in rel.split("/") {
            errors.append(
                f"tracked path inside node_modules: {rel!r}. Installed dependencies (or a symlink standing in for them) must never be committed: run `git rm --cached` on it; .gitignore's `node_modules` rule keeps it out.",
            );
        }
    }
}

impl check_agent_tool_grants -> None {
    for path in sorted((ROOT / ".claude" / "agents").rglob("*.md")) {
        rel: any = path.relative_to(ROOT).as_posix();
        try {
            data: any = _frontmatter(path.read_text(encoding="utf-8"));
        } except (OSError, UnicodeDecodeError) as exc {
            errors.append(f"{rel}: unreadable (must be UTF-8): {exc}");
            continue;
        }
        if data is None {
            errors.append(f"{rel}: missing or unterminated frontmatter (expected --- ... ---)");
            continue;
        }
        keyed: any = {_key(k): v for (k, v) in data.items()};
        mode: any = keyed.get("permissionmode");
        if mode is not None
            and `str(mode).strip().strip("'\"") not in ALLOWED_AGENT_PERMISSION_MODES
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
        if "tools" not in data or not _tool_entries(data.get("tools")) {
            errors.append(
                f"{rel}: no `tools:` key - an agent without one gets every tool, including Edit, Write and Bash. Shipped agents read untrusted posting text; declare an explicit list drawn from {sorted(ALLOWED_AGENT_TOOLS)}.",
            );
            continue;
        }
        for `entry in _tool_entries(data.get("tools")) {
            if `entry in ALLOWED_AGENT_TOOLS {
                continue;
            }
            if "(" in `entry {
                errors.append(
                    f"{rel}: tools entry {`entry!r} looks scoped but is not - an agent's `tools:` list is tool-name granularity (a `Bash(pattern)` entry gives the agent plain Bash). List the bare tool and let settings.json's allow list scope it.",
                );
                continue;
            }
            errors.append(
                f"{rel}: tools entry not in the reviewed allowlist: {`entry!r}. Shipped agent definitions read untrusted posting text, so they may not edit or write files or spawn further agents. If the grant is intentional, add it to ALLOWED_AGENT_TOOLS in tools/security_guards.jac in the same PR.",
            );
        }
    }
}

impl main -> builtins.int {
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
