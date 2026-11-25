impl _is_upstream_url(url: builtins.str) -> builtins.bool {
    lowered: any = url.strip().lower();
    slug: any = UPSTREAM.lower();
    for prefix in (_HTTPS_PREFIX, _SSH_PREFIX, _SSH_URL_PREFIX) {
        if lowered.startswith(prefix) {
            rest: any = lowered[len(prefix):].rstrip("/");
            if rest.endswith(".git") {
                rest = rest[:-len(".git")];
            }
            return operator.eq(rest, slug);
        }
    }
    return False;
}

impl is_upstream_checkout -> builtins.bool {
    env_repo: any = os.environ.get("GITHUB_REPOSITORY");
    if env_repo {
        return operator.eq(env_repo, UPSTREAM);
    }
    try {
        origin: any = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            cwd=REPO,
            capture_output=True,
            text=True,
            timeout=10,
        );
    } except (OSError, subprocess.SubprocessError) {
        return True;
    }
    if origin.returncode != 0 {
        return True;
    }
    return _is_upstream_url(origin.stdout);
}
