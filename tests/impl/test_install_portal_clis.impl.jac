impl InstallPortalClis.setUp {
    directory: TemporaryDirectory = TemporaryDirectory();
    self.addCleanup(directory.cleanup);
    self.root = Path(directory.name);
}

impl InstallPortalClis.add_cli(
    name: str, manifest: dict[str, any] = {}, base: Path | None = None
) -> Path {
    cli: Path = (base or self.root) / ".agents" / "skills" / name / "cli";
    cli.mkdir(parents=True);
    (cli / "package.json").write_text(json.dumps(manifest or {"name": name}), encoding="utf-8");
    return cli;
}

impl InstallPortalClis.install(
    base: Path, fail: str = "", dry_run: bool = False
) -> tuple[int, list[any]] {
    run: mock.Mock = mock.Mock(
        side_effect=lambda (argv: list[str], cwd: Path) -> subprocess.CompletedProcess {
            subprocess.CompletedProcess(argv, 1 if cwd.parent.name == fail else 0)
        },
    );
    with redirect_stdout(io.StringIO()) {
        code: int = install_portal_clis.install(discover(base), "bun", dry_run, base, run);
    }
    return (code, run.call_args_list);
}

impl InstallPortalClis.test_discovers_every_cli_on_the_ci_glob {
    self.add_cli("board-search");
    self.add_cli("my-market-search");
    (self.root / ".agents" / "skills" / "no-cli-skill").mkdir(parents=True);
    self.assertEqual(
        [p.parent.name for p in discover(self.root)], ["board-search", "my-market-search"]
    );
}

impl InstallPortalClis.test_install_runs_bun_only_for_safe_manifests {
    hooked: dict[str, any] = {"scripts": {"postinstall": "curl x | sh"}};
    cases: list[tuple[dict[str, dict[str, any]], str, bool, int, list[str]]] = [
        ({"safe-search": {}, "borrowed-search": hooked}, "", False, 1, ["safe-search"]),
        (
            {"a-search": {}, "b-search": {}, "c-search": {}},
            "b-search",
            False,
            1,
            ["a-search", "b-search", "c-search"],
        ),
        ({"a-search": {}}, "", False, 0, ["a-search"]),
        ({"a-search": {}}, "", True, 0, []),
    ];
    for (number, (portals, fail, dry_run, expected, installed)) in enumerate(cases) {
        with self.subTest(portals=portals, fail=fail, dry_run=dry_run) {
            base: Path = self.root / str(number);
            for (name, manifest) in portals.items() {
                self.add_cli(name, manifest, base);
            }
            (code, calls) = self.install(base, fail, dry_run);
            self.assertEqual(code, expected);
            self.assertEqual([c.kwargs["cwd"].parent.name for c in calls], installed);
            for c in calls {
                self.assertEqual(c.args, (["bun", "install", "--ignore-scripts"],));
            }
        }
    }
}

impl InstallPortalClis.test_manifests_that_run_code_or_reconfigure_the_install_are_unsafe {
    cases: list[tuple[str, dict[str, any], str]] = [
        ("trustedDependencies", {"trustedDependencies": ["y"]}, ""),
        ("workspaces", {"workspaces": ["packages/*"]}, ""),
        ("bunfig.toml", {}, "[install]\nregistry = \"https://registry.example\"\n"),
        (".npmrc", {}, "registry=https://registry.example/\n"),
    ];
    for (needle, manifest, config) in cases {
        with self.subTest(needle=needle) {
            cli: Path = self.add_cli(needle + "-search", manifest);
            if config {
                (cli / needle).write_text(config, encoding="utf-8");
            }
            self.assertIn(needle, unsafe_reason(cli));
        }
    }
}

impl InstallPortalClis.test_cli_dry_run {
    for (portal, needle) in (
        ("", "nothing to install"),
        ("board-search", "would install  board-search"),
    ) {
        with self.subTest(portal=portal) {
            if portal {
                self.add_cli(portal);
            }
            proc: subprocess.CompletedProcess = subprocess.run(
                [*tool("install_portal_clis"), "--dry-run"],
                env=rooted(self.root),
                capture_output=True,
                text=True,
                encoding="utf-8",
            );
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr);
            self.assertIn(needle, proc.stdout);
        }
    }
}

impl InstallPortalClis.test_find_bun {
    fake_bun: Path = self.root / ".bun" / "bin" / ("bun.exe" if sys.platform == "win32" else "bun");
    fake_bun.parent.mkdir(parents=True);
    fake_bun.write_text("#!/bin/sh\n", encoding="utf-8");
    fake_bun.chmod(0o755);
    cases: list[tuple[str | None, Path, str | None]] = [
        ("/custom/bin/bun", fake_bun.parent, "/custom/bin/bun"),
        (None, fake_bun.parent, str(fake_bun)),
        (None, self.root / "empty", None),
    ];
    for (on_path, candidate, expected) in cases {
        with self.subTest(on_path=on_path, candidate=candidate.name) {
            with mock.patch.object(shutil, "which", return_value=on_path) {
                found: str | None = install_portal_clis.find_bun(candidate_dirs=(str(candidate),));
            }
            self.assertEqual(found, expected);
        }
    }
    with mock.patch.object(shutil, "which", return_value="/custom/bin/bun") {
        self.assertEqual(install_portal_clis.find_bun(), "/custom/bin/bun");
    }
}

impl InstallPortalClis.test_missing_bun_message_suggests_export {
    output: io.StringIO = io.StringIO();
    cli: Path = self.root / "board-search" / "cli";
    with mock.patch.object(install_portal_clis, "find_bun", return_value=None) {
        with mock.patch.object(install_portal_clis, "discover", return_value=[cli]) {
            with redirect_stdout(output) {
                self.assertEqual(install_portal_clis.main([]), 1);
            }
        }
    }
    self.assertIn("bun was not found on PATH", output.getvalue());
    self.assertIn("export PATH=", output.getvalue());
}
