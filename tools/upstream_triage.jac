"""Triage upstream commits this fork has not picked up yet.

Prints a Markdown report sorting them into "worth reviewing" and "probably skip". It only
reads git history: nothing is merged, and the cherry-pick lines are for a human to run.
A commit is skipped when its patch-id matches a fork-only commit (already cherry-picked),
its subject matches one (verify), it is on the won't-port list, or it touches only files
this fork removed (or only CHANGELOG.md besides them).

Usage: neojac run jobsearch -- upstream_triage [--remote upstream] [--branch master]
Always exits 0; an unavailable upstream ref is a note on stderr.
"""

import argparse, shlex, subprocess, sys;
import from pathlib { Path }

"""Use UTF-8 for piped output even on legacy-console hosts."""
def _force_utf8_output {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

def git(*args: str) -> str {
    return subprocess.run(
        ["git", *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=True,
    ).stdout;
}

def rev_list(range_spec: str) -> list[str] {
    return git("rev-list", "--no-merges", "--topo-order", range_spec).split();
}

"""Stable patch-id for a commit, or None if it has no diff."""
def patch_id(sha: str) -> str | None {
    out: str = subprocess.run(
        ["git", "patch-id", "--stable"],
        input=git("show", sha),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    ).stdout;
    return out.split()[0] if out.strip() else None;
}

def subject(sha: str) -> str {
    return git("show", "-s", "--format=%s", sha).strip();
}

def files_touched(sha: str) -> list[str] {
    return [f for f in git("show", "--name-only", "--format=", sha).strip().splitlines() if f];
}

def path_exists(path: str, ref: str = "HEAD") -> bool {
    return subprocess.run(
        ["git", "cat-file", "-e", f"{ref}:{path}"], capture_output=True
    ).returncode
        == 0;
}

"""Whether a path absent from HEAD and base sits in a directory the fork removed.

The nearest ancestor directory that HEAD or the base has decides: HEAD means kept.
"""
def in_removed_dir(path: str, base: str) -> bool {
    parts: list[str] = path.split("/")[:-1];
    for depth in range(len(parts), 0, -1) {
        parent: str = "/".join(parts[:depth]);
        if path_exists(parent) {
            return False;
        }
        if path_exists(parent, base) {
            return True;
        }
    }
    return False;
}

"""owner/repo for a GitHub remote, or None if it can't be parsed."""
def remote_slug(remote: str) -> str | None {
    try {
        url: str = git("remote", "get-url", remote).strip();
    } except subprocess.CalledProcessError {
        return None;
    }
    for sep in ("github.com/", "github.com:") {
        if sep in url {
            return url.split(sep, 1)[1].removesuffix(".git");
        }
    }
    return None;
}

"""SHA prefixes the fork has decided never to port; missing file -> []."""
def load_wontport(path: str) -> list[str] {
    try {
        raw: str = Path(path).read_text(encoding="utf-8");
    } except FileNotFoundError {
        return [];
    }
    stripped: list[str] = [line.split("#", 1)[0].strip() for line in raw.splitlines()];
    return [line for line in stripped if line];
}

def commit_cell(sha: str, slug: str | None) -> str {
    return f"[`{sha[:9]}`](https://github.com/{slug}/commit/{sha})" if slug else f"`{sha[:9]}`";
}

"""Whether the commit's path matters to this fork: present, or new upstream rather than removed here."""
def relevant_path(path: str, base: str | None) -> bool {
    return path_exists(path)
        or base is None
        or not (path_exists(path, base) or in_removed_dir(path, base));
}

def main -> int {
    _force_utf8_output();
    ap = argparse.ArgumentParser();
    ap.add_argument("--remote", default="upstream");
    ap.add_argument("--branch", default="master");
    ap.add_argument("--wontport", default=".github/upstream-wontport.txt");
    args = ap.parse_args();
    ref: str = f"{args.remote}/{args.branch}";
    slug = remote_slug(args.remote);
    wontport: tuple[str, ...] = tuple(load_wontport(args.wontport));
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
    behind = rev_list(f"HEAD..{ref}");
    if not behind {
        print(f"Up to date with `{ref}`. Nothing to review. :white_check_mark:");
        _print_crossref(args.remote, args.branch);
        return 0;
    }
    fork_only = rev_list(f"{ref}..HEAD");
    fork_patch_ids: set[str | None] = {patch_id(sha) for sha in fork_only} - {None};
    fork_subjects: dict[str, str] = {};
    for sha in fork_only {
        fork_subjects.setdefault(subject(sha), sha);
    }
    try {
        common_base: str | None = git("merge-base", "HEAD", ref).strip();
    } except subprocess.CalledProcessError {
        common_base = None;
    }
    review: list[tuple[str, str, list[str]]] = [];
    skipped: list[tuple[str, str, str]] = [];
    for sha in behind {
        subj = subject(sha);
        if patch_id(sha) in fork_patch_ids {
            why: str = "already applied (cherry-picked)";
        } elif subj in fork_subjects {
            why = f"subject matches fork commit {fork_subjects[subj][:9]}, patch differs: verify";
        } elif sha.startswith(wontport) {
            why = "on the fork's won't-port list";
        } else {
            touched = files_touched(sha);
            relevant: list[str] = [f for f in touched if relevant_path(f, common_base)];
            substantive: list[str] = [f for f in relevant if f != "CHANGELOG.md"];
            if touched and not relevant {
                why = "touches only files not in this fork";
            } elif relevant and not substantive {
                why = "changelog-only footprint in this fork";
            } else {
                review.append((sha, subj, substantive));
                continue;
            }
        }
        skipped.append((sha, subj, why));
    }
    lines: list[str] = [
        f"Upstream `{ref}` has **{len(behind)}** commit(s) this fork lacks: **{len(review)}** worth reviewing, **{len(skipped)}** probably skippable.",
        "",
        "_This is a triage report. Nothing was merged - review and port by hand._",
        "",
        "### Worth reviewing",
        "",
    ];
    if review {
        lines += ["| Commit | Subject | Relevant files it touches |", "|---|---|---|"];
        for (sha, subj, present) in review {
            shown: str = ", ".join([f"`{p}`" for p in present[:4]]) or "_(new/shared paths)_";
            if len(present) > 4 {
                shown += f" +{len(present) - 4} more";
            }
            lines.append(f"| {commit_cell(sha, slug)} | {subj} | {shown} |");
        }
        lines += [
            "",
            "<details><summary>Ready-to-run cherry-picks (review each before running)</summary>",
            "",
            "```bash",
            *[f"git cherry-pick {sha}  # {subj}" for (sha, subj, _) in reversed(review)],
            "```",
            "",
            "</details>",
        ];
    } else {
        lines.append("_None._");
    }
    lines += ["", "### Probably skip", ""];
    if skipped {
        lines += ["| Commit | Subject | Why |", "|---|---|---|"];
        lines += [f"| {commit_cell(sha, slug)} | {subj} | {why} |" for (sha, subj, why) in skipped];
    } else {
        lines.append("_None._");
    }
    print("\n".join(lines));
    _print_crossref(args.remote, args.branch);
    return 0;
}

def _print_crossref(remote: str, branch: str) {
    print(
        f"\n_For personalized-file version stamps (which methodology files changed), run `neojac run jobsearch -- check_upstream_updates --remote {shlex.quote(remote)} --branch {shlex.quote(branch)}`._",
    );
}

with entry:__main__ {
    sys.exit(main());
}
