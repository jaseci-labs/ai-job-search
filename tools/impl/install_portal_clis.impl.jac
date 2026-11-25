impl discover(`root: Path = root_default_) -> builtins.list[Path] {
    return sorted(p.parent for p in (`root / ".agents" / "skills").glob("*/cli/package.json"));
}

impl unsafe_reason(cli_dir: Path) -> builtins.str | None {
    try {
        data: any = json.loads((cli_dir / "package.json").read_text(encoding="utf-8"));
    } except (OSError, json.JSONDecodeError) as exc {
        return f"unreadable package.json ({exc})";
    }
    if not isinstance(data, `dict) {
        return "package.json is not a JSON object";
    }
    scripts: any = data.get("scripts", {});
    bad: any = sorted(FORBIDDEN_SCRIPTS & `set(scripts)) if isinstance(scripts, `dict) else [];
    if bad {
        return f"declares lifecycle script(s) {bad}";
    }
    if "trustedDependencies" in data {
        return "declares trustedDependencies";
    }
    if "workspaces" in data {
        return "declares workspaces";
    }
    for name in INSTALL_CONFIG_FILES {
        if (cli_dir / name).exists() {
            return f"carries a {name}";
        }
    }
    return None;
}

impl install(
    cli_dirs: builtins.list[Path],
    bun: builtins.str,
    dry_run: builtins.bool,
    `root: Path = root_default__,
    run=run_default_,
) -> builtins.int {
    failures: any = [];
    for cli_dir in cli_dirs {
        name: any = cli_dir.parent.name;
        reason: any = unsafe_reason(cli_dir);
        if reason {
            print(
                f"SKIP  {name}: {reason} - read its code, then run `bun install` in {cli_dir.relative_to(`root).as_posix()} yourself if you trust it",
            );
            failures.append(name);
            continue;
        }
        if dry_run {
            print(f"would install  {name}");
            continue;
        }
        print(f"installing  {name}", flush=True);
        if run([bun, "install", "--ignore-scripts"], cwd=cli_dir).returncode != 0 {
            print(f"FAIL  {name}: bun install exited non-zero");
            failures.append(name);
        }
    }
    if failures {
        print(
            "\n"
                + format(len(failures), "")
                + " of "
                + format(len(cli_dirs), "")
                + " portal CLI(s) not installed: "
                + format(", ".join(failures), ""),
        );
        return 1;
    }
    verb: any = "would be installed" if dry_run else "installed";
    print(f"\nAll {len(cli_dirs)} portal CLI(s) {verb}.");
    return 0;
}

impl find_bun(candidate_dirs: any = candidate_dirs_default_) -> builtins.str | None {
    found: any = shutil.which("bun");
    if found {
        return found;
    }
    binary: any = "bun.exe" if sys.platform == "win32" else "bun";
    for dir_path in candidate_dirs {
        candidate: any = Path(dir_path).expanduser() / binary;
        comptime if target().os == "windows" {
            if candidate.is_file() {
                return `str(candidate);
            }
        } else {
            if candidate.is_file() and os.access(candidate, os.X_OK) {
                return `str(candidate);
            }
        }
    }
    return None;
}

impl _force_utf8_output -> None {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

impl main(argv=None) -> builtins.int {
    _force_utf8_output();
    ap: any = argparse.ArgumentParser(description=__doc__.splitlines()[0]);
    ap.add_argument(
        "--dry-run", action="store_true", help="list what would be installed, run nothing"
    );
    args: any = ap.parse_args(argv);

    cli_dirs: any = discover();
    if not cli_dirs {
        print("No portal CLIs found under .agents/skills/*/cli/ - nothing to install.");
        return 0;
    }
    bun: any = find_bun();
    if not bun and not args.dry_run {
        print(
            "bun was not found on PATH and was not found at any of the usual install locations.\n  - installed via bun.sh? export PATH=\"$HOME/.bun/bin:$PATH\"\n  - installed via Homebrew/Linuxbrew? brew install bun\n  - installed elsewhere? reinstall to a directory on PATH",
        );
        return 1;
    }
    if bun {
        bun_dir: any = `str(Path(bun).parent);
        if bun_dir not in os.environ.get("PATH", "").split(os.pathsep) {
            os.environ["PATH"] = bun_dir + os.pathsep + os.environ.get("PATH", "");
        }
    }
    return install(cli_dirs, bun or "bun", args.dry_run);
}
