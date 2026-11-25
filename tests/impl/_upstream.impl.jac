impl _is_upstream_url(url: str) -> bool {
    lowered = url.strip().lower();
    for prefix in GITHUB_PREFIXES {
        if lowered.startswith(prefix) {
            return lowered[len(prefix):].rstrip("/").removesuffix(".git") == UPSTREAM.lower();
        }
    }
    return False;
}

impl is_upstream_checkout -> bool {
    env_repo = os.environ.get("GITHUB_REPOSITORY");
    if env_repo {
        return env_repo == UPSTREAM;
    }
    try {
        origin = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            cwd=REPO,
            capture_output=True,
            text=True,
            timeout=10,
        );
    } except (OSError, subprocess.SubprocessError) {
        return True;
    }
    return origin.returncode != 0 or _is_upstream_url(origin.stdout);
}
