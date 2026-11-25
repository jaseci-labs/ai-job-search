"""Install the dependencies of every portal CLI under .agents/skills/.

Run from anywhere: neojac run jobsearch -- install_portal_clis [--dry-run]

Every `.agents/skills/*/cli/package.json` is discovered (the glob CI uses) and installed with
`bun install --ignore-scripts`, each independently. A manifest that declares a lifecycle
script, trustedDependencies or workspaces, or that has a bunfig.toml or .npmrc beside it, is
skipped and reported instead: tools/security_guards.jac forbids those in-tree.

Exit 0 when every CLI installed, 1 when bun is missing, a manifest was skipped, or an
install failed.
"""

import argparse, json, os, shutil, subprocess, sys;
import from pathlib { Path }

glob ROOT: Path = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent),
     _BUN_CANDIDATE_DIRS: tuple[str, ...] = (
         "~/.bun/bin",
         "/opt/homebrew/bin",
         "/usr/local/bin",
         "/home/linuxbrew/.linuxbrew/bin",
         "~/.linuxbrew/bin",
         "~/.local/bin",
         "/usr/bin",
     );

"""Each portal CLI directory, sorted by portal name."""
def discover(base: Path = ROOT) -> list[Path] {
    return sorted([p.parent for p in (base / ".agents" / "skills").glob("*/cli/package.json")]);
}

"""Why this manifest must not be installed unattended, or None when it is safe."""
def unsafe_reason(cli_dir: Path) -> str | None {
    try {
        data: any = json.loads((cli_dir / "package.json").read_text(encoding="utf-8"));
    } except (OSError, json.JSONDecodeError) as exc {
        return f"unreadable package.json ({exc})";
    }
    if not isinstance(data, dict) {
        return "package.json is not a JSON object";
    }
    scripts: any = data.get("scripts", {});
    bad: list[str] = sorted([s for s in scripts if s in FORBIDDEN_SCRIPTS])
        if isinstance(scripts, dict)
        else [];
    if bad {
        return f"declares lifecycle script(s) {bad}";
    }
    for key in ("trustedDependencies", "workspaces") {
        if key in data {
            return f"declares {key}";
        }
    }
    for name in INSTALL_CONFIG_FILES {
        if (cli_dir / name).exists() {
            return f"carries a {name}";
        }
    }
    return None;
}

def install(
    cli_dirs: list[Path], bun: str, dry_run: bool, base: Path = ROOT, run: any = subprocess.run
) -> int {
    failures: list[str] = [];
    for cli_dir in cli_dirs {
        name: str = cli_dir.parent.name;
        reason: str | None = unsafe_reason(cli_dir);
        if reason {
            print(
                f"SKIP  {name}: {reason} - read its code, then run `bun install` in {cli_dir.relative_to(base).as_posix()} yourself if you trust it",
            );
            failures.append(name);
        } elif dry_run {
            print(f"would install  {name}");
        } else {
            print(f"installing  {name}", flush=True);
            if run([bun, "install", "--ignore-scripts"], cwd=cli_dir).returncode != 0 {
                print(f"FAIL  {name}: bun install exited non-zero");
                failures.append(name);
            }
        }
    }
    if failures {
        names: str = ", ".join(failures);
        print(f"\n{len(failures)} of {len(cli_dirs)} portal CLI(s) not installed: {names}");
        return 1;
    }
    verb: str = "would be installed" if dry_run else "installed";
    print(f"\nAll {len(cli_dirs)} portal CLI(s) {verb}.");
    return 0;
}

"""`bun` on PATH, or at a standard install location."""
def find_bun(candidate_dirs: tuple[str, ...] = _BUN_CANDIDATE_DIRS) -> str | None {
    found: str | None = shutil.which("bun");
    if found {
        return found;
    }
    windows: bool = sys.platform == "win32";
    for dir_path in candidate_dirs {
        candidate: Path = Path(dir_path).expanduser() / ("bun.exe" if windows else "bun");
        if candidate.is_file() and (windows or os.access(candidate, os.X_OK)) {
            return str(candidate);
        }
    }
    return None;
}

def main(argv: list[str] | None = None) -> int {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__.splitlines()[0]);
    ap.add_argument(
        "--dry-run", action="store_true", help="list what would be installed, run nothing"
    );
    args: argparse.Namespace = ap.parse_args(argv);
    cli_dirs: list[Path] = discover();
    if not cli_dirs {
        print("No portal CLIs found under .agents/skills/*/cli/ - nothing to install.");
        return 0;
    }
    bun: str | None = find_bun();
    if not bun and not args.dry_run {
        print(
            "bun was not found on PATH and was not found at any of the usual install locations.\n  - installed via bun.sh? export PATH=\"$HOME/.bun/bin:$PATH\"\n  - installed via Homebrew/Linuxbrew? brew install bun\n  - installed elsewhere? reinstall to a directory on PATH",
        );
        return 1;
    }
    if bun {
        bun_dir: str = str(Path(bun).parent);
        if bun_dir not in os.environ.get("PATH", "").split(os.pathsep) {
            os.environ["PATH"] = bun_dir + os.pathsep + os.environ.get("PATH", "");
        }
    }
    return install(cli_dirs, bun or "bun", args.dry_run);
}

with entry:__main__ {
    sys.exit(main());
}
