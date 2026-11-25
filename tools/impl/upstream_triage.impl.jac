impl _force_utf8_output -> None {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

impl git(*args_: str) -> str {
    args: any = tuple(args_);
    return subprocess.run(
        ["git", *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=True,
    ).stdout;
}

impl rev_list(range_spec: str) -> list[str] {
    out: any = git("rev-list", "--no-merges", "--topo-order", range_spec).strip();
    return out.splitlines() if out else [];
}

impl patch_id(sha: str) -> str | None {
    show: any = subprocess.run(
        ["git", "show", sha],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=True,
    ).stdout;
    r: any = subprocess.run(
        ["git", "patch-id", "--stable"],
        input=show,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    );
    line: any = r.stdout.strip();
    return line.split()[0] if line else None;
}

impl subject(sha: str) -> str {
    return git("show", "-s", "--format=%s", sha).strip();
}

impl files_touched(sha: str) -> list[str] {
    out: any = git("show", "--name-only", "--format=", sha).strip();
    return [f for f in out.splitlines() if f];
}

impl path_exists(path: str, ref: str = "HEAD") -> bool {
    r: any = subprocess.run(["git", "cat-file", "-e", f"{ref}:{path}"], capture_output=True);
    return operator.eq(r.returncode, 0);
}

impl in_removed_dir(path: str, base: str) -> bool {
    parts: any = path.split("/")[:-1];
    for depth in range(len(parts), 0, -1) {
        parent: any = "/".join(parts[:depth]);
        if path_exists(parent) {
            return False;
        }
        if path_exists(parent, base) {
            return True;
        }
    }
    return False;
}

impl remote_slug(remote: str) -> str | None {
    try {
        url: any = git("remote", "get-url", remote).strip();
    } except subprocess.CalledProcessError {
        return None;
    }
    for sep in ("github.com/", "github.com:") {
        if sep in url {
            path: any = url.split(sep, 1)[1];
            return path[:-4] if path.endswith(".git") else path;
        }
    }
    return None;
}

impl load_wontport(path: str) -> list[str] {
    try {
        f: any;
        with open(path, encoding="utf-8") as f {
            raw: any = f.read();
        }
    } except FileNotFoundError {
        return [];
    }
    entries: any = [];
    line: any;
    for line in raw.splitlines() {
        line = line.split("#", 1)[0].strip();
        if line {
            entries.append(line);
        }
    }
    return entries;
}

impl commit_cell(short: str, sha: str, slug: str | None) -> str {
    if slug {
        return f"[`{short}`](https://github.com/{slug}/commit/{sha})";
    }
    return f"`{short}`";
}

impl main -> int {
    sha: any;
    _force_utf8_output();
    ap: any = argparse.ArgumentParser();
    ap.add_argument("--remote", default="upstream");
    ap.add_argument("--branch", default="master");
    ap.add_argument("--wontport", default=".github/upstream-wontport.txt");
    args: any = ap.parse_args();
    ref: any = f"{args.remote}/{args.branch}";
    slug: any = remote_slug(args.remote);
    wontport: any = load_wontport(args.wontport);

    try {
        git("rev-parse", "--verify", ref);
    } except subprocess.CalledProcessError {
        print(
            f"note: {ref} not available (add the remote and fetch it first); nothing to triage.",
            file=sys.stderr,
        );
        print(f"_Upstream ref `{ref}` was not available when this ran._");
        return 0;
    }

    behind: any = rev_list(f"HEAD..{ref}");
    if not behind {
        print(f"Up to date with `{ref}`. Nothing to review. :white_check_mark:");
        _print_crossref(args.remote, args.branch);
        return 0;
    }

    fork_only: any = rev_list(f"{ref}..HEAD");
    fork_patch_ids: any = {p for p in (patch_id(s) for s in fork_only) if p};
    fork_subjects: any = {};
    for fork_sha in fork_only {
        fork_subjects.setdefault(subject(fork_sha), fork_sha);
    }
    try {
        common_base: any = git("merge-base", "HEAD", ref).strip();
    } except subprocess.CalledProcessError {
        common_base = None;
    }

    review: list[tuple[str, str, str, list[str]]] = [];
    `skip: list[tuple[str, str, str, str]] = [];

    for sha_ in behind {
        sha = sha_;
        subj: any = subject(sha);
        short: any = sha[:9];
        if patch_id(sha) in fork_patch_ids {
            `skip.append((short, sha, subj, "already applied (cherry-picked)"));
            continue;
        }
        if subj in fork_subjects {
            `match: any = fork_subjects[subj][:9];
            `skip.append((
                short,
                sha,
                subj,
                f"subject matches fork commit {`match}, patch differs: verify",
            ));
            continue;
        }
        if `any([sha.startswith(e) for e in wontport]) {
            `skip.append((short, sha, subj, "on the fork's won't-port list"));
            continue;
        }
        touched: any = files_touched(sha);
        relevant: any = [
            f
            for f in touched
            if path_exists(f)
                or common_base is None
                or not (path_exists(f, common_base) or in_removed_dir(f, common_base))
        ];
        substantive: any = [f for f in relevant if f != "CHANGELOG.md"];
        if touched and not relevant {
            `skip.append((short, sha, subj, "touches only files not in this fork"));
        } elif relevant and not substantive {
            `skip.append((short, sha, subj, "changelog-only footprint in this fork"));
        } else {
            review.append((short, sha, subj, substantive));
        }
    }

    lines: list[str] = [];
    lines.append(
        f"Upstream `{ref}` has **{len(behind)}** commit(s) this fork lacks: **{len(review)}** worth reviewing, **{len(`skip)}** probably skippable.",
    );
    lines.append("");
    lines.append("_This is a triage report. Nothing was merged - review and port by hand._");
    lines.append("");

    lines.append("### Worth reviewing");
    if review {
        lines.append("");
        lines.append("| Commit | Subject | Relevant files it touches |");
        lines.append("|---|---|---|");
        present: any;
        for item_ in review {
            (short, sha, subj, present) = item_;
            shown: any = ", ".join(f"`{p}`" for p in present[:4]) or "_(new/shared paths)_";
            if len(present) > 4 {
                shown += f" +{len(present) - 4} more";
            }
            lines.append(f"| {commit_cell(short, sha, slug)} | {subj} | {shown} |");
        }
        lines.append("");
        lines.append(
            "<details><summary>Ready-to-run cherry-picks (review each before running)</summary>"
        );
        lines.append("");
        lines.append("```bash");
        _: any;
        for item__ in reversed(review) {
            (short, sha, subj, _) = item__;
            lines.append(f"git cherry-pick {sha}  # {subj}");
        }
        lines.append("```");
        lines.append("");
        lines.append("</details>");
    } else {
        lines.append("");
        lines.append("_None._");
    }
    lines.append("");

    lines.append("### Probably skip");
    if `skip {
        lines.append("");
        lines.append("| Commit | Subject | Why |");
        lines.append("|---|---|---|");
        why: any;
        for item___ in `skip {
            (short, sha, subj, why) = item___;
            lines.append(f"| {commit_cell(short, sha, slug)} | {subj} | {why} |");
        }
    } else {
        lines.append("");
        lines.append("_None._");
    }

    print("\n".join(lines));
    _print_crossref(args.remote, args.branch);
    return 0;
}

impl _print_crossref(remote: str, branch: str) -> None {
    print();
    print(
        f"_For personalized-file version stamps (which methodology files changed), run `neojac run jobsearch -- check_upstream_updates --remote {shlex.quote(remote)} --branch {shlex.quote(branch)}`._",
    );
}
