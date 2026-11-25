"""Lint the repo's skill, command, and settings files.

Run from anywhere: neojac run jobsearch -- lint_skills

Checks:
- Every SKILL.md (.claude/skills/*, .agents/skills/*) has YAML frontmatter that parses, with
  non-empty `name` and `description` keys
- `allowed-tools` entries of the form `Bash(bun run <path> *)` point at files that exist
  (paths resolve relative to the repo root and to .agents/)
- Every .claude/commands/*.md starts with a `# /<name>` title
- .claude/settings.json is valid JSON with a permissions.allow list

Exit code 0 on success, 1 with a failure list otherwise.
"""

import json, os, re, sys;
import from pathlib { Path }

glob yaml: any;

glob ROOT: Path = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent),
     errors: list[str] = [];

with entry {
    try {
        import yaml;
    } except ImportError {
        sys.exit("lint_skills.jac requires PyYAML: neojac install");
    }
}

def fail(path: Path, message: str) {
    errors.append(f"{path.relative_to(ROOT)}: {message}");
}

def check_skill(path: Path) {
    text: str = path.read_text(encoding="utf-8");
    end: int = text.find("\n---", 4);
    if not text.startswith("---\n") {
        fail(path, "missing YAML frontmatter (file must start with ---)");
        return;
    }
    if end == -1 {
        fail(path, "unterminated YAML frontmatter");
        return;
    }
    try {
        data: any = yaml.safe_load(text[4:end]);
    } except yaml.YAMLError as exc {
        fail(path, f"frontmatter is not valid YAML: {exc}");
        return;
    }
    if not isinstance(data, dict) {
        fail(path, "frontmatter did not parse to a mapping");
        return;
    }
    for key in ("name", "description") {
        if not data.get(key) {
            fail(path, f"frontmatter missing required key '{key}'");
        }
    }
    allowed: any = data.get("allowed-tools", "");
    bases: tuple[Path, Path] = (ROOT, ROOT / ".agents");
    for found in re.finditer("bun run ([^\\s)]+)", allowed if isinstance(allowed, str) else "") {
        target: str = found.group(1).rstrip("*");
        if not target or target.endswith("/") {
            continue;
        }
        if "*" in target {
            if not any([list(base.glob(target)) for base in bases]) {
                fail(path, f"allowed-tools glob matches no files: {target}");
            }
        } elif not any([(base / target).is_file() for base in bases]) {
            fail(path, f"allowed-tools references a missing file: {target}");
        }
    }
}

def check_command(path: Path) {
    lines: list[str] = path.read_text(encoding="utf-8").lstrip().splitlines();
    first: str = lines[0] if lines else "";
    if not first.startswith("# /") {
        fail(path, f"command file must start with a '# /<name>' title (found: {first[:50]!r})");
    }
}

def check_settings {
    try {
        data: any = json.loads((ROOT / ".claude" / "settings.json").read_text(encoding="utf-8"));
    } except (OSError, json.JSONDecodeError) as exc {
        errors.append(f".claude/settings.json: {exc}");
        return;
    }
    permissions: any = data.get("permissions", {}) if isinstance(data, dict) else None;
    problem: str = "";
    if not isinstance(data, dict) {
        problem = "top-level JSON value to be an object";
    } elif not isinstance(permissions, dict) {
        problem = "permissions to be an object";
    } elif not isinstance(permissions.get("allow"), list) {
        problem = "permissions.allow to be a list";
    }
    if problem {
        errors.append(f".claude/settings.json: expected {problem}");
    }
}

def main -> int {
    skills: list[Path] = sorted(ROOT.glob(".claude/skills/*/SKILL.md"))
        + sorted(ROOT.glob(".agents/skills/*/SKILL.md"));
    commands: list[Path] = sorted((ROOT / ".claude" / "commands").glob("*.md"));
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

with entry:__main__ {
    sys.exit(main());
}
