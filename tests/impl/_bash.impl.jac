impl find_bash -> str | None {
    candidates: list[str | None] = [shutil.which("bash")];
    git = shutil.which("git") if WINDOWS else None;
    if git {
        candidates.append(str(Path(git).resolve().parent.parent / "bin" / "bash.exe"));
    }
    for candidate in dict.fromkeys(candidates) {
        if not candidate {
            continue;
        }
        try {
            probe = subprocess.run(
                [candidate, "-c", "x=ok; test \"$x\" = ok"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5,
            );
        } except (OSError, subprocess.SubprocessError) {
            continue;
        }
        if probe.returncode == 0 {
            return candidate;
        }
    }
    return None;
}
