"""Report framework files whose 'framework_version' is newer in the upstream repository.

Usage: neojac run jobsearch -- check_upstream_updates [--remote <remote-name>] [--branch <branch-name>]

Fetches the upstream remote (default 'upstream', falling back to 'origin') and compares
the version stamps of the local framework files with those at the upstream ref.
"""

import argparse, os, re, shlex, subprocess, sys;
import from pathlib { Path }

glob ROOT: Path = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent),
     FRAMEWORK_FILES: list[str] = [
         f".claude/skills/job-application-assistant/{name}.md"
         for name in ("01-candidate-profile 02-behavioral-profile 03-writing-style 04-job-evaluation"
             " 05-cv-templates 06-cover-letter-templates 07-interview-prep"
             " 08-application-forms 09-web-research SKILL").split()
     ] + ["AGENTS.md"],
     UPSTREAM_REPO_SLUG: str = "ai-job-search-dev/ai-job-search";

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

def get_remote_url(remote_name: str) -> str {
    (rc, stdout, _) = run_git(["remote", "get-url", remote_name]);
    return stdout.strip() if rc == 0 else "";
}

def get_framework_version_from_text(text: str) -> str | None {
    end = text.find("\n---", 4);
    if not text.startswith("---\n") or end == -1 {
        return None;
    }
    for line in text[4:end].splitlines() {
        (key, _, value) = line.partition(":");
        if ":" in line and key.strip() == "framework_version" {
            return value.strip().strip("\"").strip("'");
        }
    }
    return None;
}

def parse_semver(version_str: str) -> tuple[int, int, int] {
    found = re.match("^v?(\\d+)\\.(\\d+)\\.(\\d+)", version_str);
    return (int(found[1]), int(found[2]), int(found[3])) if found else (0, 0, 0);
}

"""Use UTF-8 for piped output even on legacy-console hosts."""
def _force_utf8_output {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

def main -> int {
    _force_utf8_output();
    parser = argparse.ArgumentParser(description="Check for framework updates upstream.");
    parser.add_argument(
        "--remote",
        default="upstream",
        help="Name of the git remote for upstream (default: upstream)",
    );
    parser.add_argument(
        "--branch", default="master", help="Branch name of the upstream repo (default: master)"
    );
    parser.add_argument("--no-fetch", action="store_true", help="Skip fetching from remote");
    args = parser.parse_args();
    remotes: list[str] = run_git(["remote"])[1].splitlines();
    remote: str = args.remote;
    if remote not in remotes {
        if "origin" not in remotes {
            print("Error: No git remotes found.");
            return 1;
        }
        print(f"Warning: Remote '{remote}' not found. Falling back to 'origin'.");
        remote = "origin";
        if UPSTREAM_REPO_SLUG.lower() not in get_remote_url(remote).lower() {
            print(
                f"Warning: Remote '{remote}' does not point to the ai-job-search template repo ({UPSTREAM_REPO_SLUG}), so this check compares your fork against itself and will never report upstream updates. Add the template repo as a remote to track upstream changes, e.g.:\n  git remote add upstream https://github.com/{UPSTREAM_REPO_SLUG}.git",
            );
        }
    }
    fetch_failed: bool = False;
    if not args.no_fetch {
        print(f"Fetching latest from remote '{remote}'...");
        (rc, _, stderr) = run_git(["fetch", remote]);
        fetch_failed = rc != 0;
        if fetch_failed {
            print(f"Warning: Failed to fetch from remote '{remote}': {stderr.strip()}");
            print("Proceeding with cached remote tracking branches.");
        }
    }
    ref: str = f"{remote}/{args.branch}";
    if run_git(["rev-parse", "--verify", ref])[0] != 0 {
        print(
            f"Error: Ref '{ref}' does not exist. Make sure you fetched and specified the correct branch.",
        );
        return 1;
    }
    print(f"Comparing local files against upstream '{ref}'...\n");
    updates: list[str] = [];
    errors: list[str] = [];
    missing_upstream: list[str] = [];
    for rel_path in FRAMEWORK_FILES {
        local_path = ROOT / rel_path;
        if not local_path.exists() {
            errors.append(f"Local file missing: {rel_path}");
            continue;
        }
        local_ver = get_framework_version_from_text(local_path.read_text(encoding="utf-8"));
        (rc, upstream_text, git_err) = run_git(["show", f"{ref}:{rel_path}"]);
        if rc != 0 {
            if "does not exist" in git_err or "exists on disk, but not in" in git_err {
                missing_upstream.append(rel_path);
            } else {
                errors.append(f"Failed to read upstream version of {rel_path}: {git_err.strip()}");
            }
            continue;
        }
        upstream_ver = get_framework_version_from_text(upstream_text);
        if not local_ver or not upstream_ver {
            side: str = "Upstream" if local_ver else "Local";
            errors.append(f"{side} file {rel_path} is missing 'framework_version' in frontmatter.");
        } elif parse_semver(upstream_ver) > parse_semver(local_ver) {
            updates.append(
                f"  - {Path(rel_path).name}: local {local_ver} < upstream {upstream_ver}\n    Diff command: git diff {ref} -- {rel_path}\n",
            );
        }
    }
    if errors {
        print("Configuration errors:", *errors, sep="\n  - ");
        print();
    }
    if missing_upstream {
        print(
            "Files present locally but missing from the upstream ref (possibly renamed or deleted upstream):",
            *missing_upstream,
            sep="\n  - ",
        );
        print();
    }
    if updates {
        print("[UPDATE] Upstream updates available for framework methodology files:");
        print(*updates, sep="\n");
        print("Review these changes to see if they fit your personalized fork!");
    } elif errors or missing_upstream {
        print(
            f"[WARNING] Framework check incomplete against {ref}: {len(errors)} configuration error(s), {len(missing_upstream)} file(s) missing upstream. Review the messages above before assuming you are up to date.",
        );
    } elif not fetch_failed {
        print(f"[OK] All framework files are up to date with {ref}!");
    }
    if fetch_failed {
        print(
            f"[WARNING] Compared against cached {ref} because the fetch failed; the current upstream state could not be checked.",
        );
    }
    print(
        f"\nFor commit-level triage of upstream commits, run: neojac run jobsearch -- upstream_triage --remote {shlex.quote(remote)} --branch {shlex.quote(args.branch)}",
    );
    return 0;
}

with entry:__main__ {
    sys.exit(main());
}
