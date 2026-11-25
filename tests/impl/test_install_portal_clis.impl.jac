impl install(*args_) -> any {
    args: any = tuple(args_);
    with redirect_stdout(io.StringIO()) {
        return install_portal_clis.install(*args);
    }
}

impl FakeRun.init(fail=()) {
    self.calls = [];
    self.fail = `set(fail);
}

impl FakeRun.__call__(argv, cwd) -> any {
    self.calls.append(Path(cwd).parent.name);
    self.argvs = getattr(self, "argvs", []) + [`list(argv)];
    return subprocess.CompletedProcess(argv, 1 if Path(cwd).parent.name in self.fail else 0);
}

impl InstallPortalClis.setUp -> any {
    directory: any = TemporaryDirectory();
    self.addCleanup(directory.cleanup);
    self.root = Path(directory.name);
}

impl InstallPortalClis.add_cli(name, manifest=None) -> any {
    cli: any = self.root / ".agents" / "skills" / name / "cli";
    cli.mkdir(parents=True);
    (cli / "package.json").write_text(json.dumps(manifest or {"name": name}), encoding="utf-8");
    return cli;
}

impl InstallPortalClis.test_discovers_every_cli_on_the_ci_glob -> any {
    self.add_cli("board-search");
    self.add_cli("my-market-search");
    (self.root / ".agents" / "skills" / "no-cli-skill").mkdir(parents=True);
    self.assertEqual(
        [p.parent.name for p in discover(self.root)], ["board-search", "my-market-search"]
    );
}

impl InstallPortalClis.test_lifecycle_script_is_skipped_not_run -> any {
    self.add_cli("safe-search");
    self.add_cli("borrowed-search", {"scripts": {"postinstall": "curl x | sh"}});
    run: any = FakeRun();
    self.assertEqual(install(discover(self.root), "bun", False, self.root, run), 1);
    self.assertEqual(run.calls, ["safe-search"]);
}

impl InstallPortalClis.test_trusted_dependencies_is_unsafe -> any {
    self.assertIn(
        "trustedDependencies", unsafe_reason(self.add_cli("x", {"trustedDependencies": ["y"]}))
    );
}

impl InstallPortalClis.test_workspaces_is_unsafe -> any {
    self.assertIn("workspaces", unsafe_reason(self.add_cli("x", {"workspaces": ["packages/*"]})));
}

impl InstallPortalClis.test_bunfig_is_unsafe -> any {
    cli: any = self.add_cli("x");
    (cli / "bunfig.toml").write_text(
        "[install]\nregistry = \"https://registry.example\"\n", encoding="utf-8"
    );
    self.assertIn("bunfig.toml", unsafe_reason(cli));
}

impl InstallPortalClis.test_npmrc_is_unsafe -> any {
    cli: any = self.add_cli("x");
    (cli / ".npmrc").write_text("registry=https://registry.example/\n", encoding="utf-8");
    self.assertIn(".npmrc", unsafe_reason(cli));
}

impl InstallPortalClis.test_bun_install_never_runs_lifecycle_scripts -> any {
    self.add_cli("a-search");
    run: any = FakeRun();
    self.assertEqual(install(discover(self.root), "bun", False, self.root, run), 0);
    self.assertEqual(run.argvs, [["bun", "install", "--ignore-scripts"]]);
}

impl InstallPortalClis.test_one_failure_does_not_stop_the_rest -> any {
    for name in ("a-search", "b-search", "c-search") {
        self.add_cli(name);
    }
    run: any = FakeRun(fail={"b-search"});
    self.assertEqual(install(discover(self.root), "bun", False, self.root, run), 1);
    self.assertEqual(run.calls, ["a-search", "b-search", "c-search"]);
}

impl InstallPortalClis.test_dry_run_runs_nothing -> any {
    self.add_cli("a-search");
    run: any = FakeRun();
    self.assertEqual(install(discover(self.root), "bun", True, self.root, run), 0);
    self.assertEqual(run.calls, []);
}

impl InstallPortalClis.run_script -> any {
    return subprocess.run(
        [*tool("install_portal_clis"), "--dry-run"],
        env=rooted(self.root),
        capture_output=True,
        text=True,
        encoding="utf-8",
    );
}

impl InstallPortalClis.test_cli_with_no_portals_installed_succeeds -> any {
    proc: any = self.run_script();
    self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr);
    self.assertIn("nothing to install", proc.stdout);
}

impl InstallPortalClis.test_cli_dry_run_lists_a_copied_in_portal -> any {
    self.add_cli("board-search");
    proc: any = self.run_script();
    self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr);
    self.assertIn("would install  board-search", proc.stdout);
}

impl FindBun.setUp -> any {
    directory: any = TemporaryDirectory();
    self.addCleanup(directory.cleanup);
    self.root = Path(directory.name);
}

impl FindBun.test_find_bun_prefers_path -> any {
    import shutil;
    orig_which: any = shutil.which;
    shutil.which = lambda (name) -> any { "/custom/bin/bun" if name == "bun" else None };
    self.addCleanup(builtins.setattr, shutil, "which", orig_which);

    self.assertEqual(install_portal_clis.find_bun(), "/custom/bin/bun");
}

impl FindBun.test_find_bun_falls_back_to_candidate_directory -> any {
    import shutil;
    orig_which: any = shutil.which;
    shutil.which = lambda (name) -> any { None };
    self.addCleanup(builtins.setattr, shutil, "which", orig_which);

    binary: any = "bun.exe" if sys.platform == "win32" else "bun";
    fake_bin: any = self.root / ".bun" / "bin";
    fake_bin.mkdir(parents=True);
    fake_bun: any = fake_bin / binary;
    fake_bun.write_text("#!/bin/sh\n", encoding="utf-8");
    comptime if target().os != "windows" {
        fake_bun.chmod(493);
    }

    found: any = install_portal_clis.find_bun(candidate_dirs=(`str(fake_bin),));
    self.assertEqual(found, `str(fake_bun));
}

impl FindBun.test_find_bun_returns_none_when_missing -> any {
    import shutil;
    orig_which: any = shutil.which;
    shutil.which = lambda (name) -> any { None };
    self.addCleanup(builtins.setattr, shutil, "which", orig_which);

    self.assertIsNone(install_portal_clis.find_bun(candidate_dirs=(`str(self.root / "empty"),)));
}

impl FindBun.test_missing_bun_message_suggests_export -> any {
    output: any = io.StringIO();
    orig_find: any = vars(install_portal_clis)["find_bun"];
    vars(install_portal_clis)["find_bun"] = lambda (*args__, **kwargs) -> any {
        args: any = tuple(args__);
        return None;
    };
    self.addCleanup(builtins.setattr, install_portal_clis, "find_bun", orig_find);
    orig_discover: any = vars(install_portal_clis)["discover"];
    vars(install_portal_clis)["discover"] = lambda -> any { [self.root / "board-search" / "cli"] };
    self.addCleanup(builtins.setattr, install_portal_clis, "discover", orig_discover);

    with redirect_stdout(output) {
        rc: any = install_portal_clis.main([]);
    }
    self.assertEqual(rc, 1);
    text: any = output.getvalue();
    self.assertIn("bun was not found on PATH", text);
    self.assertIn("export PATH=", text);
}
