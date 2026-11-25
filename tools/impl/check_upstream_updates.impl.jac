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

impl get_remote_url(remote_name: str) -> str {
    rc: any;
    stdout: any;
    _: any;
    (rc, stdout, _) = run_git(["remote", "get-url", remote_name]) as any;
    return stdout.strip() if rc == 0 else "";
}

impl get_framework_version_from_text(text: str) -> str | None {
    if not text.startswith("---\n") {
        return None;
    }
    end: any = text.find("\n---", 4);
    if end == -1 {
        return None;
    }
    for line in text[4:end].splitlines() {
        if ":" in line {
            k: any;
            v: any;
            (k, v) = line.split(":", 1) as any;
            if k.strip() == "framework_version" {
                return v.strip().strip("\"").strip("'");
            }
        }
    }
    return None;
}

impl parse_semver(version_str: str) -> tuple[int, int, int] {
    `match: any = re.match("^v?(\\d+)\\.(\\d+)\\.(\\d+)", version_str);
    if not `match {
        return (0, 0, 0);
    }
    return `tuple(`int(x) for x in `match.groups());
}

impl _force_utf8_output -> None {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

impl main -> int {
    _force_utf8_output();
    parser: any = argparse.ArgumentParser(description="Check for framework updates upstream.");
    parser.add_argument(
        "--remote",
        default="upstream",
        help="Name of the git remote for upstream (default: upstream)",
    );
    parser.add_argument(
        "--branch", default="master", help="Branch name of the upstream repo (default: master)"
    );
    parser.add_argument("--no-fetch", action="store_true", help="Skip fetching from remote");
    args: any = parser.parse_args();
    rc: any;
    stdout: any;
    _: any;
    (rc, stdout, _) = run_git(["remote"]) as any;
    remotes: any = stdout.splitlines();
    remote: any = args.remote;
    if remote not in remotes {
        if "origin" in remotes {
            print(f"Warning: Remote '{remote}' not found. Falling back to 'origin'.");
            remote = "origin";
        } else {
            print("Error: No git remotes found.");
            return 1;
        }
    }
    if remote != args.remote and UPSTREAM_REPO_SLUG.lower() not in get_remote_url(remote).lower() {
        print(
            f"Warning: Remote '{remote}' does not point to the ai-job-search template repo ({UPSTREAM_REPO_SLUG}), so this check compares your fork against itself and will never report upstream updates. Add the template repo as a remote to track upstream changes, e.g.:\n  git remote add upstream https://github.com/{UPSTREAM_REPO_SLUG}.git",
        );
    }

    fetch_failed: any = False;
    if not args.no_fetch {
        print(f"Fetching latest from remote '{remote}'...");
        stderr: any;
        (rc, _, stderr) = run_git(["fetch", remote]) as any;
        if rc != 0 {
            fetch_failed = True;
            print(f"Warning: Failed to fetch from remote '{remote}': {stderr.strip()}");
            print("Proceeding with cached remote tracking branches.");
        }
    }

    ref: any = f"{remote}/{args.branch}";
    (rc, _, _) = run_git(["rev-parse", "--verify", ref]) as any;
    if rc != 0 {
        print(
            f"Error: Ref '{ref}' does not exist. Make sure you fetched and specified the correct branch.",
        );
        return 1;
    }

    print(f"Comparing local files against upstream '{ref}'...\n");

    updates_available: any = [];
    errors: any = [];
    missing_upstream: any = [];

    for rel_path in FRAMEWORK_FILES {
        local_path: any = ROOT / rel_path;
        if not local_path.exists() {
            errors.append(f"Local file missing: {rel_path}");
            continue;
        }
        local_text: any = local_path.read_text(encoding="utf-8");
        local_ver: any = get_framework_version_from_text(local_text);
        upstream_text: any;
        git_err: any;
        (rc, upstream_text, git_err) = run_git(["show", f"{ref}:{rel_path}"]) as any;
        if rc != 0 {
            if "does not exist" in git_err or "exists on disk, but not in" in git_err {
                missing_upstream.append(rel_path);
            } else {
                errors.append(f"Failed to read upstream version of {rel_path}: {git_err.strip()}");
            }
            continue;
        }

        upstream_ver: any = get_framework_version_from_text(upstream_text);

        if not local_ver {
            errors.append(f"Local file {rel_path} is missing 'framework_version' in frontmatter.");
            continue;
        }
        if not upstream_ver {
            errors.append(
                f"Upstream file {rel_path} is missing 'framework_version' in frontmatter."
            );
            continue;
        }

        if parse_semver(upstream_ver) > parse_semver(local_ver) {
            updates_available.append({
                "filename": Path(rel_path).name,
                "local": local_ver,
                "upstream": upstream_ver,
                "path": rel_path,
            });
        }
    }

    if errors {
        print("Configuration errors:");
        for err in errors {
            print(f"  - {err}");
        }
        print();
    }

    if missing_upstream {
        print(
            "Files present locally but missing from the upstream ref (possibly renamed or deleted upstream):",
        );
        for path in missing_upstream {
            print(f"  - {path}");
        }
        print();
    }

    if updates_available {
        print("[UPDATE] Upstream updates available for framework methodology files:");
        for up in updates_available {
            print(
                "  - "
                    + format(up["filename"], "")
                    + ": local "
                    + format(up["local"], "")
                    + " < upstream "
                    + format(up["upstream"], ""),
            );
            print(
                "    Diff command: git diff " + format(ref, "") + " -- " + format(up["path"], "")
            );
            print();
        }
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
