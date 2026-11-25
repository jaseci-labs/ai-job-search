impl rel(path: Path) -> builtins.str {
    return `str(path.relative_to(ROOT));
}

impl check_skill(path: Path) -> None {
    text: any = path.read_text(encoding="utf-8");
    if not text.startswith("---\n") {
        errors.append(f"{rel(path)}: missing YAML frontmatter (file must start with ---)");
        return;
    }
    end: any = text.find("\n---", 4);
    if end == -1 {
        errors.append(f"{rel(path)}: unterminated YAML frontmatter");
        return;
    }
    try {
        data: any = yaml.safe_load(text[4:end]);
    } except yaml.YAMLError as exc {
        errors.append(f"{rel(path)}: frontmatter is not valid YAML: {exc}");
        return;
    }
    if not isinstance(data, `dict) {
        errors.append(f"{rel(path)}: frontmatter did not parse to a mapping");
        return;
    }
    for key in ("name", "description") {
        if not data.get(key) {
            errors.append(f"{rel(path)}: frontmatter missing required key '{key}'");
        }
    }

    allowed: any = data.get("allowed-tools", "");
    if isinstance(allowed, `str) {
        for `match in re.finditer("bun run ([^\\s)]+)", allowed) {
            target: any = `match.group(1).rstrip("*");
            if not target or target.endswith("/") {
                continue;
            }
            if "*" in target {
                if not `list(ROOT.glob(target)) and not `list((ROOT / ".agents").glob(target)) {
                    errors.append(f"{rel(path)}: allowed-tools glob matches no files: {target}");
                }
            } else {
                candidates: any = [ROOT / target, ROOT / ".agents" / target];
                if not `any(c.is_file() for c in candidates) {
                    errors.append(
                        f"{rel(path)}: allowed-tools references a missing file: {target}"
                    );
                }
            }
        }
    }
}

impl check_command(path: Path) -> None {
    lines: any = path.read_text(encoding="utf-8").lstrip().splitlines();
    first: any = lines[0] if lines else "";
    if not first.startswith("# /") {
        errors.append(
            f"{rel(path)}: command file must start with a '# /<name>' title (found: {first[:50]!r})"
        );
    }
}

impl check_settings -> None {
    path: any = ROOT / ".claude" / "settings.json";
    try {
        data: any = json.loads(path.read_text(encoding="utf-8"));
    } except (OSError, json.JSONDecodeError) as exc {
        errors.append(f".claude/settings.json: {exc}");
        return;
    }
    if not isinstance(data, `dict) {
        errors.append(".claude/settings.json: expected top-level JSON value to be an object");
        return;
    }
    permissions: any = data.get("permissions", {});
    if not isinstance(permissions, `dict) {
        errors.append(".claude/settings.json: expected permissions to be an object");
        return;
    }
    if not isinstance(permissions.get("allow"), `list) {
        errors.append(".claude/settings.json: expected permissions.allow to be a list");
    }
}

impl main -> builtins.int {
    skills: any = sorted(ROOT.glob(".claude/skills/*/SKILL.md"))
        + sorted(ROOT.glob(".agents/skills/*/SKILL.md"));
    commands: any = sorted((ROOT / ".claude" / "commands").glob("*.md"));
    if not skills {
        errors.append("no SKILL.md files found - glob roots are wrong or the tree moved");
    }
    if not commands {
        errors.append("no command files found under .claude/commands/");
    }

    for skill in skills {
        check_skill(skill);
    }
    for command in commands {
        check_command(command);
    }
    check_settings();

    if errors {
        print(f"lint_skills: {len(errors)} failure(s)");
        for err in errors {
            print(f"  - {err}");
        }
        return 1;
    }
    print(f"lint_skills: OK ({len(skills)} skills, {len(commands)} commands, settings.json)");
    return 0;
}
