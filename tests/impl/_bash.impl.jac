impl find_bash -> any {
    candidates: any = [shutil.which("bash")];
    if WINDOWS {
        git: any = shutil.which("git");
        if git {
            candidates.append(`str(Path(git).resolve().parent.parent / "bin" / "bash.exe"));
        }
    }
    for candidate in dict.fromkeys(candidates) {
        if not candidate {
            continue;
        }
        try {
            result: any = subprocess.run(
                [candidate, "-c", "x=ok; test \"$x\" = ok"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5,
            );
        } except (OSError, subprocess.SubprocessError) {
            continue;
        }
        if result.returncode == 0 {
            return candidate;
        }
    }
    return None;
}
