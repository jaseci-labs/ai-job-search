impl run_git(args: list[str]) -> tuple[int, str, str] {
    res: any = subprocess.run(
        ["git"] + args,
        cwd=`str(ROOT),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    );
    return (res.returncode, res.stdout, res.stderr);
}

impl get_base_commit -> str | None {
    base_ref: any = os.environ.get("GITHUB_BASE_REF");
    if base_ref {
        rc: any;
        _: any;
        (rc, _, _) = run_git(["rev-parse", "--verify", f"origin/{base_ref}"]) as any;
        if rc == 0 {
            return f"origin/{base_ref}";
        }
        (rc, _, _) = run_git(["rev-parse", "--verify", base_ref]) as any;
        if rc == 0 {
            return base_ref;
        }
    }
    if os.environ.get("GITHUB_ACTIONS") {
        (rc, _, _) = run_git(["rev-parse", "--verify", "HEAD~1"]) as any;
        if rc == 0 {
            return "HEAD~1";
        }
    }
    (rc, _, _) = run_git(["rev-parse", "--verify", "HEAD"]) as any;
    if rc == 0 {
        return "HEAD";
    }

    return None;
}

impl parse_frontmatter(path: Path) -> dict {
    if not path.exists() {
        return {};
    }
    return parse_frontmatter_text(path.read_text(encoding="utf-8"));
}

impl parse_frontmatter_text(text: str) -> dict {
    if not text.startswith("---\n") {
        return {};
    }
    end: any = text.find("\n---", 4);
    if end == -1 {
        return {};
    }
    data: any = {};
    for line in text[4:end].splitlines() {
        if ":" in line {
            k: any;
            v: any;
            (k, v) = line.split(":", 1) as any;
            data[k.strip()] = v.strip().strip("\"").strip("'");
        }
    }
    return data;
}

impl has_non_trivial_changes(file_path: Path, base_commit: str) -> bool {
    rel_path: any = file_path.relative_to(ROOT).as_posix();
    rc: any;
    stdout: any;
    stderr: any;
    (rc, stdout, stderr) = run_git(["diff", "-U0", base_commit, "--", rel_path]) as any;
    if rc != 0 {
        return True;
    }
    meaningful_changes: any = 0;
    version_changed: any = False;

    for line in stdout.splitlines() {
        if line.startswith("+++") or line.startswith("---") or line.startswith("@@") {
            continue;
        }
        if line.startswith("+") or line.startswith("-") {
            content: any = line[1:].strip();
            if not content {
                continue;
            }
            if re.match("^framework_version\\s*:", content) {
                version_changed = True;
                continue;
            }
            if content == "---" {
                continue;
            }
            meaningful_changes += 1;
        }
    }
    if version_changed {
        base_text: any;
        _: any;
        (rc, base_text, _) = run_git(["show", f"{base_commit}:{rel_path}"]) as any;
        if rc != 0
            or parse_frontmatter_text(base_text).get("framework_version")
                != parse_frontmatter(file_path).get("framework_version")
        {
            return False;
        }
    }
    return operator.gt(meaningful_changes, 0);
}

impl main -> int {
    errors: any = [];
    path: any;
    for path in FRAMEWORK_FILES {
        rel_path: any = path.relative_to(ROOT).as_posix();
        fm: any = parse_frontmatter(path);
        if "framework_version" not in fm {
            errors.append(f"{rel_path}: missing 'framework_version' in frontmatter");
        }
    }
    base_commit: any = get_base_commit();
    if base_commit {
        print(f"Comparing HEAD against base commit: {base_commit}");
        for path in FRAMEWORK_FILES {
            rel_path = path.relative_to(ROOT).as_posix();
            if "framework_version" not in parse_frontmatter(path) {
                continue;
            }
            if has_non_trivial_changes(path, base_commit) {
                errors.append(
                    f"{rel_path}: modified without bumping 'framework_version'. Please update the version in the frontmatter.",
                );
            }
        }
    } else {
        print(
            "No base commit found (e.g. initial commit or shallow clone without base branch). Skipping diff checks.",
        );
    }

    if errors {
        print("Framework Version Check Failed:");
        for err in errors {
            print(f"  - {err}");
        }
        return 1;
    }

    print("Framework Version Check: OK");
    return 0;
}
