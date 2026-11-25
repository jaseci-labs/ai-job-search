"""CI check: every framework file carries a 'framework_version' frontmatter key,
and none is modified in git without that version being bumped.

Framework files are the markdown files of .claude/skills/job-application-assistant/ and AGENTS.md.
"""

import os, re, subprocess, sys;
import from pathlib { Path }

glob ROOT: Path = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent),
     SKILL_DIR: Path = ROOT / ".claude/skills/job-application-assistant",
     FRAMEWORK_FILES: list[Path] = sorted(SKILL_DIR.glob("*.md")) + [
         p
         for p in [ROOT / "AGENTS.md"]
         if p.exists()
     ],
     VERSION_LINE: str = "^framework_version\\s*:";

def run_git(args: list[str]) -> tuple[int, str, str] {
    res = subprocess.run(
        ["git"] + args,
        cwd=str(ROOT),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    );
    return (res.returncode, res.stdout, res.stderr);
}

"""The ref to diff against: the pull request's base, the previous commit in CI, else HEAD."""
def get_base_commit -> str | None {
    base_ref = os.environ.get("GITHUB_BASE_REF");
    candidates: list[str] = ([f"origin/{base_ref}", base_ref] if base_ref else [])
        + (["HEAD~1"] if os.environ.get("GITHUB_ACTIONS") else [])
        + ["HEAD"];
    for candidate in candidates {
        if run_git(["rev-parse", "--verify", candidate])[0] == 0 {
            return candidate;
        }
    }
    return None;
}

def parse_frontmatter(path: Path) -> dict[str, str] {
    return parse_frontmatter_text(path.read_text(encoding="utf-8")) if path.exists() else {};
}

def parse_frontmatter_text(text: str) -> dict[str, str] {
    end = text.find("\n---", 4);
    if not text.startswith("---\n") or end == -1 {
        return {};
    }
    data: dict[str, str] = {};
    for line in text[4:end].splitlines() {
        if ":" in line {
            (key, _, value) = line.partition(":");
            data[key.strip()] = value.strip().strip("\"").strip("'");
        }
    }
    return data;
}

"""Whether the file changed since base_commit without its framework_version changing."""
def has_non_trivial_changes(file_path: Path, base_commit: str) -> bool {
    rel_path = file_path.relative_to(ROOT).as_posix();
    (rc, stdout, _) = run_git(["diff", "-U0", base_commit, "--", rel_path]);
    if rc != 0 {
        return True;
    }
    changed: list[str] = [
        line[1:].strip()
        for line in stdout.splitlines()
        if line[:1] in ("+", "-") and not line.startswith(("+++", "---"))
    ];
    if any([re.match(VERSION_LINE, content) for content in changed]) {
        (rc, base_text, _) = run_git(["show", f"{base_commit}:{rel_path}"]);
        if rc != 0
            or parse_frontmatter_text(base_text).get("framework_version")
                != parse_frontmatter(file_path).get("framework_version")
        {
            return False;
        }
    }
    return any([
        content and content != "---" and not re.match(VERSION_LINE, content)
        for content in changed
    ]);
}

def main -> int {
    unversioned: list[Path] = [
        path
        for path in FRAMEWORK_FILES
        if "framework_version" not in parse_frontmatter(path)
    ];
    errors: list[str] = [
        f"{path.relative_to(ROOT).as_posix()}: missing 'framework_version' in frontmatter"
        for path in unversioned
    ];
    base_commit = get_base_commit();
    if base_commit {
        print(f"Comparing HEAD against base commit: {base_commit}");
        errors += [
            f"{path.relative_to(ROOT).as_posix()}: modified without bumping 'framework_version'. Please update the version in the frontmatter."
            for path in FRAMEWORK_FILES
            if path not in unversioned and has_non_trivial_changes(path, base_commit)
        ];
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

with entry:__main__ {
    sys.exit(main());
}
