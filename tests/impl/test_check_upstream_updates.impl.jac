impl UpstreamCheckerRepoFixture.setUp -> any {
    self.root = Path(tempfile.mkdtemp());
    self.addCleanup(shutil.rmtree, self.root, ignore_errors=True);

    tools: any = self.root / "tools";
    tools.mkdir();
    root_at(self, self.root);

    for rel in FRAMEWORK_FILES {
        path: any = self.root / rel;
        path.parent.mkdir(parents=True, exist_ok=True);
        path.write_text(FRONTMATTER, encoding="utf-8");
    }

    subprocess.run(["git", "init", "-b", "master"], cwd=self.root, check=True, capture_output=True);
    subprocess.run(
        ["git", "config", "user.name", "Test"], cwd=self.root, check=True, capture_output=True
    );
    subprocess.run(
        ["git", "config", "user.email", "test@example.com"],
        cwd=self.root,
        check=True,
        capture_output=True,
    );
    subprocess.run(["git", "add", "-A"], cwd=self.root, check=True, capture_output=True);
    subprocess.run(["git", "commit", "-m", "init"], cwd=self.root, check=True, capture_output=True);
}

impl UpstreamCheckerRepoFixture.add_remote(name: builtins.str, url: builtins.str) -> None {
    subprocess.run(
        ["git", "remote", "add", name, url], cwd=self.root, check=True, capture_output=True
    );
}

impl UpstreamCheckerRepoFixture.materialize_remote_ref(name: builtins.str) -> None {
    subprocess.run(
        ["git", "update-ref", f"refs/remotes/{name}/master", "HEAD"],
        cwd=self.root,
        check=True,
        capture_output=True,
    );
}

impl UpstreamCheckerRepoFixture.run_checker(*args_) -> subprocess.CompletedProcess {
    args: any = tuple(args_);
    return subprocess.run(
        [*tool("check_upstream_updates"), "--no-fetch", *args],
        cwd=self.root,
        capture_output=True,
        text=True,
    );
}

impl UpstreamCheckerRepoFixture.run_checker_with_fetch(*args__) -> subprocess.CompletedProcess {
    args: any = tuple(args__);
    return subprocess.run(
        [*tool("check_upstream_updates"), *args], cwd=self.root, capture_output=True, text=True
    );
}

impl ForkWithoutUpstreamRemoteTests.setUp -> any {
    super.setUp();
    self.add_remote("origin", FORK_URL);
    self.materialize_remote_ref("origin");
}

impl ForkWithoutUpstreamRemoteTests.test_fork_fallback_warns_that_check_is_against_own_fork -> any {
    result: any = self.run_checker("--remote", "upstream");

    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
    self.assertIn("Falling back to 'origin'", result.stdout);
    self.assertIn("does not point to the ai-job-search template repo", result.stdout);
    self.assertNotIn("up to date with upstream!", result.stdout);
    self.assertIn("up to date with origin/master", result.stdout);
}

impl DirectCloneFallbackTests.setUp -> any {
    super.setUp();
    self.add_remote("origin", TEMPLATE_URL);
    self.materialize_remote_ref("origin");
}

impl DirectCloneFallbackTests.test_clone_of_template_falls_back_without_fork_warning -> any {
    result: any = self.run_checker("--remote", "upstream");

    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
    self.assertIn("Falling back to 'origin'", result.stdout);
    self.assertNotIn("does not point to the ai-job-search template repo", result.stdout);
    self.assertIn("up to date with origin/master", result.stdout);
}

impl DirectCloneFallbackTests.test_clone_with_lowercased_template_url_falls_back_without_fork_warning -> any {
    subprocess.run(
        ["git", "remote", "set-url", "origin", TEMPLATE_URL.lower()],
        cwd=self.root,
        check=True,
        capture_output=True,
    );

    result: any = self.run_checker("--remote", "upstream");

    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
    self.assertIn("Falling back to 'origin'", result.stdout);
    self.assertNotIn("does not point to the ai-job-search template repo", result.stdout);
}

impl UpstreamRemotePresentTests.setUp -> any {
    super.setUp();
    self.add_remote("origin", FORK_URL);
    self.add_remote("upstream", TEMPLATE_URL);
    self.materialize_remote_ref("upstream");
}

impl UpstreamRemotePresentTests.test_explicit_upstream_remote_is_used_without_warning -> any {
    result: any = self.run_checker();

    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
    self.assertNotIn("Falling back to 'origin'", result.stdout);
    self.assertNotIn("does not point to the ai-job-search template repo", result.stdout);
    self.assertIn("up to date with upstream/master", result.stdout);
}

impl FailedFetchTests.test_cached_ref_after_failed_fetch_is_not_reported_as_current -> any {
    self.add_remote("upstream", `str(self.root / "unavailable-remote"));
    self.materialize_remote_ref("upstream");

    result: any = self.run_checker_with_fetch();

    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
    self.assertIn("Failed to fetch", result.stdout);
    self.assertIn("cached", result.stdout.lower());
    self.assertIn("[WARNING]", result.stdout);
    self.assertNotIn("[OK]", result.stdout);
}

impl UpstreamRefMissingFileTests.setUp -> any {
    super.setUp();
    self.add_remote("origin", FORK_URL);
    self.add_remote("upstream", TEMPLATE_URL);
    subprocess.run(
        ["git", "rm", "-q", "AGENTS.md"], cwd=self.root, check=True, capture_output=True
    );
    subprocess.run(
        ["git", "commit", "-qm", "drop AGENTS.md"], cwd=self.root, check=True, capture_output=True
    );
    self.materialize_remote_ref("upstream");
    (self.root / "AGENTS.md").write_text(FRONTMATTER, encoding="utf-8");
}

impl UpstreamRefMissingFileTests.test_file_missing_upstream_is_reported_instead_of_silent_ok -> any {
    result: any = self.run_checker();

    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
    self.assertIn("AGENTS.md", result.stdout);
    self.assertNotIn("[OK] All framework files are up to date", result.stdout);
    self.assertIn("[WARNING]", result.stdout);
}

impl LegacyEncodingTests.setUp -> any {
    super.setUp();
    for rel in FRAMEWORK_FILES {
        shutil.copy(REPO_ROOT / rel, self.root / rel);
    }
    subprocess.run(["git", "add", "-A"], cwd=self.root, check=True, capture_output=True);
    subprocess.run(
        ["git", "commit", "-qm", "copy actual framework files"],
        cwd=self.root,
        check=True,
        capture_output=True,
    );
    self.add_remote("upstream", TEMPLATE_URL);
    self.materialize_remote_ref("upstream");
}

impl LegacyEncodingTests.run_legacy_checker(*args___, ascii_git_codec=True) -> any {
    args: any = tuple(args___);
    env: any = `dict(
        os.environ,
        LC_ALL="C",
        LANG="C",
        PYTHONUTF8="0",
        PYTHONCOERCECLOCALE="0",
        PYTHONIOENCODING="cp1252",
    );
    if not ascii_git_codec {
        env["PYTHONUTF8"] = "1";
    }
    return subprocess.run(
        [*tool("check_upstream_updates"), "--no-fetch", *args],
        cwd=self.root,
        env=env,
        capture_output=True,
    );
}

impl LegacyEncodingTests.test_actual_framework_prose_is_decoded_as_utf8 -> any {
    result: any = self.run_legacy_checker();
    self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", "replace"));
    self.assertIn("[OK]", result.stdout.decode("utf-8"));
}

impl LegacyEncodingTests.test_non_latin_branch_is_printed_as_utf8 -> any {
    branch: any = "release-版本";
    subprocess.run(
        ["git", "update-ref", f"refs/remotes/upstream/{branch}", "HEAD"],
        cwd=self.root,
        check=True,
        capture_output=True,
    );
    result: any = self.run_legacy_checker("--branch", branch, ascii_git_codec=False);
    self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", "replace"));
    self.assertIn(f"upstream/{branch}", result.stdout.decode("utf-8"));
}

impl IncompleteComparisonTests.setUp -> any {
    super.setUp();
    self.add_remote("upstream", TEMPLATE_URL);
    self.materialize_remote_ref("upstream");
}

impl IncompleteComparisonTests.test_missing_local_file_does_not_report_all_files_up_to_date -> any {
    (self.root / "AGENTS.md").unlink();

    result: any = self.run_checker();

    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
    self.assertIn("AGENTS.md", result.stdout);
    self.assertIn("[WARNING] Framework check incomplete", result.stdout);
    self.assertNotIn("[OK]", result.stdout);
}

impl IncompleteComparisonTests.test_missing_upstream_marker_does_not_report_all_files_up_to_date -> any {
    agents: any = self.root / "AGENTS.md";
    agents.write_text("# Upstream guidelines without a version marker\n", encoding="utf-8");
    subprocess.run(["git", "add", "AGENTS.md"], cwd=self.root, check=True, capture_output=True);
    subprocess.run(
        ["git", "commit", "-qm", "remove upstream version marker"],
        cwd=self.root,
        check=True,
        capture_output=True,
    );
    self.materialize_remote_ref("upstream");
    agents.write_text(FRONTMATTER, encoding="utf-8");

    result: any = self.run_checker();

    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
    self.assertIn("AGENTS.md", result.stdout);
    self.assertIn("[WARNING] Framework check incomplete", result.stdout);
    self.assertNotIn("[OK]", result.stdout);
}
