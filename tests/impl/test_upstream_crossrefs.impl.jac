impl CompanionRefTests.setUp -> any {
    super.setUp();
    source: any = Path(__file__).resolve().parent.parent;
    self.remote = "forks/template";
    self.branch = self.branch_name;
    self.add_remote(self.remote, `str(self.root));
    self.git("update-ref", f"refs/remotes/{self.remote}/master", "HEAD");
    agents: any = self.root / "AGENTS.md";
    agents.write_text(FRONTMATTER.replace("1.0.0", "2.0.0"), encoding="utf-8");
    self.git("add", "AGENTS.md");
    self.git("commit", "-qm", "update next-release methodology");
    self.git("branch", self.branch);
    self.git("update-ref", f"refs/remotes/{self.remote}/{self.branch}", "HEAD");
    self.git("reset", "--hard", "HEAD~1");
}

impl CompanionRefTests.git(*args_) -> any {
    args: any = tuple(args_);
    return subprocess.run(["git", *args], cwd=self.root, check=True, capture_output=True);
}

impl CompanionRefTests.follow(command) -> any {
    words: any = shlex.split(command);
    self.assertEqual(words[:4], ["neojac", "run", "jobsearch", "--"], command);
    argv: any = [*tool(words[4]), *words[5:]];
    result: any = subprocess.run(
        argv, cwd=self.root, capture_output=True, text=True, encoding="utf-8"
    );
    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
    return result.stdout;
}

impl CompanionRefTests.test_version_checker_companion_uses_selected_remote_and_branch -> any {
    result: any = self.run_checker("--remote", self.remote, "--branch", self.branch);
    self.assertEqual(result.returncode, 0, result.stderr);
    self.assertIn("[UPDATE]", result.stdout);
    command: any = result.stdout.split("run: ", 1)[1].strip();
    companion: any = self.follow(command);
    self.assertIn(f"{self.remote}/{self.branch}", companion);
    self.assertIn("**1** worth reviewing", companion);
}

impl CompanionRefTests.test_triage_companion_uses_selected_remote_and_branch -> any {
    result: any = subprocess.run(
        [*tool("upstream_triage"), "--remote", self.remote, "--branch", self.branch],
        cwd=self.root,
        capture_output=True,
        text=True,
        encoding="utf-8",
    );
    self.assertEqual(result.returncode, 0, result.stderr);
    self.assertIn("**1** worth reviewing", result.stdout);
    command: any = re.search(
        "run `(neojac run jobsearch -- check_upstream_updates [^`]+)`", result.stdout
    ).group(1);
    companion: any = self.follow(command);
    self.assertIn(f"{self.remote}/{self.branch}", companion);
    self.assertIn("[UPDATE]", companion);
}
