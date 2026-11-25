"""Install the dependencies of every portal CLI under .agents/skills/.

Run from anywhere: neojac run jobsearch -- install_portal_clis [--dry-run]

Every `.agents/skills/*/cli/package.json` is discovered (the glob CI uses) and installed with
`bun install --ignore-scripts`, each independently. A manifest that declares a lifecycle
script, trustedDependencies or workspaces, or that has a bunfig.toml or .npmrc beside it, is
skipped and reported instead: tools/security_guards.jac forbids those in-tree.

Exit 0 when every CLI installed, 1 when bun is missing, a manifest was skipped, or an
install failed.
"""

import argparse;
import json;
import os;
import shutil;
import subprocess;
import sys;
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
def discover(base: Path = ROOT) -> list[Path];

"""Why this manifest must not be installed unattended, or None when it is safe."""
def unsafe_reason(cli_dir: Path) -> str | None;

def install(
    cli_dirs: list[Path], bun: str, dry_run: bool, base: Path = ROOT, run: any = subprocess.run
) -> int;

"""`bun` on PATH, or at a standard install location."""
def find_bun(candidate_dirs: tuple[str, ...] = _BUN_CANDIDATE_DIRS) -> str | None;

def main(argv: list[str] | None = None) -> int;

with entry:__main__ {
    sys.exit(main());
}
