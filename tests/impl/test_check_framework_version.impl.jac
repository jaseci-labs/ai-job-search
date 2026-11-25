impl CheckerRepoFixture.setUp -> any {
    self.root = Path(tempfile.mkdtemp());
    self.addCleanup(shutil.rmtree, self.root, ignore_errors=True);

    tools: any = self.root / "tools";
    tools.mkdir();
    root_at(self, self.root);

    self.skill_dir = self.root / ".claude" / "skills" / "job-application-assistant";
    self.skill_dir.mkdir(parents=True);
    self.framework_file = self.skill_dir / "01-test-profile.md";
    self.framework_file.write_text(FRONTMATTER + BODY, encoding="utf-8");

    self.git("init", "-q");
    self.git("add", "-A");
    self.git("commit", "-q", "-m", "base");
}

impl CheckerRepoFixture.git(*args_) -> any {
    args: any = tuple(args_);
    subprocess.run(
        ["git", "-c", "user.name=test", "-c", "user.email=test@example.com", *args],
        cwd=self.root,
        check=True,
        capture_output=True,
        text=True,
    );
}

impl CheckerRepoFixture.run_checker -> any {
    env: any = {k: v for (k, v) in os.environ.items() if not k.startswith("GITHUB_")};
    return subprocess.run(
        [*tool("check_framework_version")], capture_output=True, text=True, env=env
    );
}

impl FrameworkVersionGateTests.test_clean_tree_passes -> any {
    result: any = self.run_checker();

    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
    self.assertIn("Framework Version Check: OK", result.stdout);
}

impl FrameworkVersionGateTests.test_unbumped_edit_fails -> any {
    self.framework_file.write_text(
        FRONTMATTER + BODY + "\nA new sentence without a version bump.\n", encoding="utf-8"
    );

    result: any = self.run_checker();

    self.assertEqual(result.returncode, 1, result.stdout + result.stderr);
    self.assertIn("modified without bumping 'framework_version'", result.stdout);
}

impl FrameworkVersionGateTests.test_bumped_edit_passes -> any {
    bumped: any = FRONTMATTER.replace("1.0.0", "1.0.1");
    self.framework_file.write_text(
        bumped + BODY + "\nA new sentence with a version bump.\n", encoding="utf-8"
    );

    result: any = self.run_checker();

    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
}

impl FrameworkVersionGateTests.test_same_version_reformatted_does_not_count_as_a_bump -> any {
    for marker in ["framework_version: \"1.0.0\"", "framework_version:  1.0.0"] {
        with self.subTest(marker=marker) {
            self.framework_file.write_text(
                FRONTMATTER.replace("framework_version: 1.0.0", marker)
                    + BODY
                    + "\nChanged guidance with the same version.\n",
                encoding="utf-8",
            );
            result: any = self.run_checker();
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr);
            self.assertIn("modified without bumping 'framework_version'", result.stdout);
        }
    }
}

impl FrameworkVersionGateTests.test_reformatting_version_alone_remains_allowed -> any {
    self.framework_file.write_text(
        FRONTMATTER.replace("framework_version: 1.0.0", "framework_version: \"1.0.0\"") + BODY,
        encoding="utf-8",
    );
    result: any = self.run_checker();
    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
}

impl FrameworkVersionGateTests.test_file_without_version_marker_fails -> any {
    (self.skill_dir / "02-unmarked.md").write_text("# No frontmatter at all\n", encoding="utf-8");

    result: any = self.run_checker();

    self.assertEqual(result.returncode, 1, result.stdout + result.stderr);
    self.assertIn("missing 'framework_version'", result.stdout);
}

impl WindowsGitPathTests.test_diff_and_show_use_posix_paths_for_windows_checkout -> any {
    module: any = check_framework_version;
    `root: any = PureWindowsPath("C:/checkout");
    profile: any = `root / ".claude/skills/job-application-assistant/01-test-profile.md";
    relative: any = ".claude/skills/job-application-assistant/01-test-profile.md";
    diff: any = "-framework_version: 1.0.0\n+framework_version: \"1.0.0\"\n-Old guidance\n+New guidance\n";
    run_git: any;
    with unittest.mock.patch.object(module, "ROOT", `root), unittest.mock.patch.object(
        module, "run_git", side_effect=[(0, diff, ""), (0, FRONTMATTER + BODY, "")]
    ) as run_git, unittest.mock.patch.object(
        module, "parse_frontmatter", return_value={"framework_version": "1.0.0"}
    ) {
        self.assertTrue(module.has_non_trivial_changes(profile, "base"));
    }
    self.assertEqual(
        run_git.call_args_list,
        [
            unittest.mock.call(["diff", "-U0", "base", "--", relative]),
            unittest.mock.call(["show", f"base:{relative}"]),
        ],
    );
}

impl RunGitEncodingTests.test_run_git_pins_utf8_encoding -> any {
    module: any = check_framework_version;

    mock_run: any;
    with unittest.mock.patch.object(module.subprocess, "run") as mock_run {
        mock_run.return_value = subprocess.CompletedProcess(
            args=["git"], returncode=0, stdout="", stderr=""
        );
        module.run_git(["diff", "-U0", "HEAD"]);
    }

    _: any;
    kwargs: any;
    (_, kwargs) = mock_run.call_args as any;
    self.assertEqual(
        kwargs.get("encoding"),
        "utf-8",
        "run_git() must pass encoding=\"utf-8\" to subprocess.run() - omitting it falls back to the host locale's default codec (cp1252 on Windows), which crashes on non-ASCII diff content.",
    );
}
