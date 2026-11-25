impl git(`root: Path, *args_: builtins.str) -> builtins.str {
    args: any = tuple(args_);
    return subprocess.run(
        ["git", *args], cwd=`root, check=True, capture_output=True, text=True
    ).stdout;
}

impl TriageRepoFixture.setUp -> any {
    self.root = Path(tempfile.mkdtemp());
    self.addCleanup(shutil.rmtree, self.root, ignore_errors=True);

    (self.root / "tools").mkdir();
    (self.root / ".github").mkdir();

    git(self.root, "init", "-b", "master");
    git(self.root, "config", "user.name", "Test");
    git(self.root, "config", "user.email", "test@example.com");
    git(self.root, "remote", "add", "upstream", f"https://github.com/{UPSTREAM_SLUG}.git");

    self.write("shared.txt", "base\n");
    self.write("kept.py", "print('hi')\n");
    self.commit("init");
}

impl TriageRepoFixture.write(rel: builtins.str, text: builtins.str) -> None {
    path: any = self.root / rel;
    path.parent.mkdir(parents=True, exist_ok=True);
    path.write_text(text, encoding="utf-8");
}

impl TriageRepoFixture.commit(msg: builtins.str) -> builtins.str {
    git(self.root, "add", "-A");
    git(self.root, "commit", "-m", msg);
    return git(self.root, "rev-parse", "HEAD").strip();
}

impl TriageRepoFixture.set_upstream_to_head -> None {
    git(self.root, "update-ref", "refs/remotes/upstream/master", "HEAD");
}

impl TriageRepoFixture.run_triage(*args__) -> subprocess.CompletedProcess {
    args: any = tuple(args__);
    return subprocess.run(
        [*tool("upstream_triage"), *args], cwd=self.root, capture_output=True, text=True
    );
}

impl UpToDateTests.test_reports_up_to_date_when_not_behind -> any {
    self.set_upstream_to_head();
    result: any = self.run_triage();
    self.assertEqual(result.returncode, 0, result.stderr);
    self.assertIn("Up to date", result.stdout);
}

impl RelevanceFilterTests.test_commit_touching_only_removed_files_is_skipped -> any {
    self.write("portals/removed_portal.py", "x = 1\n");
    self.commit("shared: add portal");
    self.write("portals/removed_portal.py", "x = 2\n");
    self.commit("upstream: update portal");
    self.set_upstream_to_head();
    git(self.root, "reset", "--hard", "HEAD~1");
    git(self.root, "rm", "portals/removed_portal.py");
    self.commit("fork: remove demo portal");

    result: any = self.run_triage();
    self.assertEqual(result.returncode, 0, result.stderr);
    self.assertIn("touches only files not in this fork", result.stdout);
    self.assertIn("Probably skip", result.stdout);
}

impl RelevanceFilterTests.test_commit_touching_kept_files_is_worth_reviewing -> any {
    self.write("kept.py", "print('changed')\n");
    self.commit("upstream: change kept.py");
    self.set_upstream_to_head();
    git(self.root, "reset", "--hard", "HEAD~1");

    result: any = self.run_triage();
    self.assertEqual(result.returncode, 0, result.stderr);
    self.assertIn("Worth reviewing", result.stdout);
    self.assertIn("kept.py", result.stdout);
    self.assertIn("git cherry-pick", result.stdout);
}

impl RelevanceFilterTests.test_changelog_only_footprint_is_skipped -> any {
    self.write("portals/gone.py", "y = 1\n");
    self.write("CHANGELOG.md", "- base\n");
    self.commit("shared: add portal and changelog");
    self.write("portals/gone.py", "y = 2\n");
    self.write("CHANGELOG.md", "- did a thing\n");
    self.commit("upstream: feature living in removed area + changelog");
    self.set_upstream_to_head();
    git(self.root, "reset", "--hard", "HEAD~1");
    git(self.root, "rm", "portals/gone.py");
    self.commit("fork: remove demo portal");

    result: any = self.run_triage();
    self.assertEqual(result.returncode, 0, result.stderr);
    self.assertIn("changelog-only footprint in this fork", result.stdout);
}

impl RelevanceFilterTests.test_new_upstream_tool_is_worth_reviewing -> any {
    self.write("tools/new_workflow.py", "print('new workflow')\n");
    added: any = self.commit("upstream: add a new workflow tool");
    self.set_upstream_to_head();
    git(self.root, "reset", "--hard", "HEAD~1");
    before: any = git(self.root, "status", "--porcelain");

    result: any = self.run_triage();

    self.assertEqual(result.returncode, 0, result.stderr);
    self.assertIn("**1** worth reviewing", result.stdout);
    self.assertIn("tools/new_workflow.py", result.stdout);
    self.assertIn(f"git cherry-pick {added}", result.stdout);
    self.assertEqual(git(self.root, "status", "--porcelain"), before);
    self.assertFalse((self.root / "tools/new_workflow.py").exists());
}

impl RelevanceFilterTests.test_new_file_in_removed_directory_is_skipped -> any {
    self.write("portals/gone/cli/src/cli.ts", "run()\n");
    self.commit("shared: add portal");
    self.write("portals/gone/cli/tests/new.test.ts", "test()\n");
    self.commit("upstream: add a test to the portal");
    self.set_upstream_to_head();
    git(self.root, "reset", "--hard", "HEAD~1");
    git(self.root, "rm", "-r", "portals/gone");
    self.commit("fork: remove demo portal");

    result: any = self.run_triage();

    self.assertEqual(result.returncode, 0, result.stderr);
    self.assertIn("**0** worth reviewing", result.stdout);
    self.assertIn("touches only files not in this fork", result.stdout);
}

impl RelevanceFilterTests.test_new_directory_inside_kept_directory_is_worth_reviewing -> any {
    self.write("portals/kept/cli.ts", "run()\n");
    self.commit("shared: add portal");
    self.write("portals/kept/tests/new/case.test.ts", "test()\n");
    added: any = self.commit("upstream: add nested tests to a kept portal");
    self.set_upstream_to_head();
    git(self.root, "reset", "--hard", "HEAD~1");

    result: any = self.run_triage();

    self.assertEqual(result.returncode, 0, result.stderr);
    self.assertIn("**1** worth reviewing", result.stdout);
    self.assertIn(f"git cherry-pick {added}", result.stdout);
}

impl RelevanceFilterTests.test_new_tool_with_changelog_is_not_changelog_only -> any {
    self.write("CHANGELOG.md", "- base\n");
    self.commit("shared: add changelog");
    self.write("tools/new_workflow.py", "print('new workflow')\n");
    self.write("CHANGELOG.md", "- new workflow tool\n");
    added: any = self.commit("upstream: ship a new tool and changelog");
    self.set_upstream_to_head();
    git(self.root, "reset", "--hard", "HEAD~1");

    result: any = self.run_triage();

    self.assertEqual(result.returncode, 0, result.stderr);
    self.assertIn("**1** worth reviewing", result.stdout);
    self.assertIn(f"git cherry-pick {added}", result.stdout);
    self.assertNotIn("changelog-only footprint in this fork", result.stdout);
}

impl AlreadyAppliedTests.test_cherry_picked_commit_drops_off_via_patch_id -> any {
    self.write("kept.py", "print('feature')\n");
    upstream_sha: any = self.commit("upstream: add feature");
    self.write("shared.txt", "upstream edit\n");
    self.commit("upstream: unrelated change");
    self.set_upstream_to_head();
    git(self.root, "reset", "--hard", "HEAD~2");
    self.write("fork_only.txt", "mine\n");
    self.commit("fork: divergent commit");
    git(self.root, "cherry-pick", upstream_sha);

    result: any = self.run_triage();
    self.assertEqual(result.returncode, 0, result.stderr);
    self.assertIn("already applied (cherry-picked)", result.stdout);
    self.assertIn("**1** worth reviewing", result.stdout);
}

impl SubjectCollisionTests.test_different_patch_with_same_subject_requests_verification -> any {
    self.write("kept.py", "print('upstream fix')\n");
    upstream_sha: any = self.commit("Fix configuration");
    self.set_upstream_to_head();
    git(self.root, "reset", "--hard", "HEAD~1");
    self.write("shared.txt", "fork configuration\n");
    fork_sha: any = self.commit("Fix configuration");

    result: any = self.run_triage();
    self.assertEqual(result.returncode, 0, result.stderr);
    self.assertIn("**0** worth reviewing", result.stdout);
    self.assertIn(
        f"subject matches fork commit {fork_sha[:9]}, patch differs: verify", result.stdout
    );
    self.assertNotIn(f"git cherry-pick {upstream_sha}", result.stdout);
    self.assertNotIn("already applied (cherry-picked)", result.stdout);
}

impl SubjectCollisionTests.test_conflict_resolved_personalized_port_has_distinct_verify_reason -> any {
    profile: any = ".claude/skills/job-application-assistant/01-candidate-profile.md";
    self.write(profile, "Name: template\nGuidance: old\n");
    self.commit("Add template profile");
    self.write(profile, "Name: template\nGuidance: improved\n");
    upstream_sha: any = self.commit("Improve profile guidance");
    self.set_upstream_to_head();
    git(self.root, "reset", "--hard", "HEAD~1");
    self.write(profile, "Name: personal\nGuidance: old\n");
    self.commit("Personalize profile");
    picked: any = subprocess.run(
        ["git", "cherry-pick", upstream_sha], cwd=self.root, capture_output=True, text=True
    );
    self.assertNotEqual(picked.returncode, 0, "fixture must exercise a real conflict");
    self.write(profile, "Name: personal\nGuidance: improved\n");
    git(self.root, "add", profile);
    git(self.root, "cherry-pick", "--continue");
    fork_sha: any = git(self.root, "rev-parse", "HEAD").strip();
    result: any = self.run_triage();
    self.assertEqual(result.returncode, 0, result.stderr);
    self.assertIn("**0** worth reviewing", result.stdout);
    self.assertIn(
        f"subject matches fork commit {fork_sha[:9]}, patch differs: verify", result.stdout
    );
    self.assertNotIn("already applied (cherry-picked)", result.stdout);
}

impl SubjectCollisionTests.test_same_patch_with_renamed_subject_is_still_already_applied -> any {
    self.write("kept.py", "print('upstream fix')\n");
    upstream_sha: any = self.commit("Fix configuration");
    self.set_upstream_to_head();
    git(self.root, "reset", "--hard", "HEAD~1");
    self.write("fork_only.txt", "fork\n");
    self.commit("Fork configuration");
    git(self.root, "cherry-pick", upstream_sha);
    git(self.root, "commit", "--amend", "-m", "Port upstream configuration fix");

    result: any = self.run_triage();
    self.assertEqual(result.returncode, 0, result.stderr);
    self.assertIn("**0** worth reviewing", result.stdout);
    self.assertIn("already applied (cherry-picked)", result.stdout);
}

impl SuggestedCherryPickOrderTests.test_suggested_commands_apply_dependent_changes_in_ancestry_order -> any {
    self.write("kept.py", "print('first upstream change')\n");
    first: any = self.commit("Introduce shared behavior");
    self.write("kept.py", "print('second upstream change')\n");
    second: any = self.commit("Refine shared behavior");
    self.set_upstream_to_head();
    git(self.root, "reset", "--hard", "HEAD~2");
    self.write("fork_only.txt", "fork customization\n");
    self.commit("Customize fork");

    result: any = self.run_triage();
    self.assertEqual(result.returncode, 0, result.stderr);
    commands: any = [
        line.split("  #", 1)[0].split()
        for line in result.stdout.splitlines()
        if line.startswith("git cherry-pick ")
    ];
    self.assertEqual(len(commands), 2, result.stdout);
    for command in commands {
        replay: any = subprocess.run(command, cwd=self.root, capture_output=True, text=True);
        self.assertEqual(replay.returncode, 0, replay.stdout + replay.stderr);
    }
    self.assertEqual([command[2] for command in commands], [first, second]);
    self.assertEqual((self.root / "kept.py").read_text(), "print('second upstream change')\n");
}

impl WontPortTests.test_listed_sha_is_excluded -> any {
    self.write("kept.py", "print('rejected feature')\n");
    rejected: any = self.commit("upstream: feature the fork rejects");
    self.set_upstream_to_head();
    git(self.root, "reset", "--hard", "HEAD~1");
    self.write(".github/upstream-wontport.txt", f"{rejected[:9]}  # rejected on purpose\n");
    self.commit("fork: won't-port list");

    result: any = self.run_triage();
    self.assertEqual(result.returncode, 0, result.stderr);
    self.assertIn("on the fork's won't-port list", result.stdout);
}

impl MissingUpstreamRefTests.test_missing_ref_degrades_gracefully -> any {
    result: any = self.run_triage();
    self.assertEqual(result.returncode, 0, result.stderr);
    self.assertIn("was not available", result.stdout);
}

impl WorkflowGuardTests.test_workflow_is_guarded_against_upstream -> any {
    text: any = WORKFLOW.read_text(encoding="utf-8");
    self.assertIn(f"github.repository != '{UPSTREAM_SLUG}'", text);
}

impl WorkflowGuardTests.test_workflow_uses_builtin_token_only -> any {
    text: any = WORKFLOW.read_text(encoding="utf-8");
    self.assertIn("GH_TOKEN: ${{ github.token }}", text);
    self.assertNotIn("secrets.", text);
}

impl WorkflowGuardTests.test_actions_are_sha_pinned -> any {
    text: any = WORKFLOW.read_text(encoding="utf-8");
    for line in text.splitlines() {
        stripped: any = line.strip();
        if stripped.startswith("- uses:") or stripped.startswith("uses:") {
            ref: any = stripped.split("uses:", 1)[1].strip();
            self.assertIn("@", ref);
            sha: any = ref.split("@", 1)[1].split()[0];
            self.assertRegex(sha, "^[0-9a-f]{40}$", f"action not SHA-pinned: {ref}");
        }
    }
}
