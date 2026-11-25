import io;
import json;
import shutil;
import subprocess;
import sys;
import unittest;
import from contextlib { redirect_stdout }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest { mock }

class InstallPortalClis(unittest.TestCase) {
    def setUp;
    def add_cli(name: str, manifest: dict[str, any] = {}, base: Path | None = None) -> Path;
    def install(base: Path, fail: str = "", dry_run: bool = False) -> tuple[int, list[any]];
    def test_discovers_every_cli_on_the_ci_glob;
    def test_install_runs_bun_only_for_safe_manifests;
    def test_manifests_that_run_code_or_reconfigure_the_install_are_unsafe;
    def test_cli_dry_run;
    def test_find_bun;
    def test_missing_bun_message_suggests_export;
}

with entry:__main__ {
    unittest.main();
}
