impl settings_cases -> list[tuple[str, str]] {
    shapes: list[tuple[str, list[any]]] = [
        ("top-level JSON value to be an object", [[], "settings", 1, None]),
        (
            "expected permissions to be an object",
            [{"permissions": p} for p in ([], "permissions", 1, None)],
        ),
        (
            "expected permissions.allow to be a list",
            [{"permissions": {"allow": a}} for a in ({}, "Bash(bun run:*)", 1, None)],
        ),
    ];
    return [("{not json", SETTINGS)] + [
        (json.dumps(data), message)
        for (message, datas) in shapes
        for data in datas
    ];
}

impl LintSkillsTests.setUp {
    self.root = Path(tempfile.mkdtemp());
    self.addCleanup(shutil.rmtree, self.root, ignore_errors=True);
    root_at(self, self.root);
}

impl LintSkillsTests.lint(files: dict[str, str]) -> subprocess.CompletedProcess {
    shutil.rmtree(self.root / ".claude", ignore_errors=True);
    for (rel, text) in {**VALID, **files}.items() {
        (self.root / rel).parent.mkdir(parents=True, exist_ok=True);
        (self.root / rel).write_text(text, encoding="utf-8");
    }
    result: subprocess.CompletedProcess = subprocess.run(
        tool("lint_skills"), capture_output=True, text=True
    );
    self.assertNotIn("Traceback", result.stderr);
    return result;
}

impl LintSkillsTests.test_valid_tree_passes {
    result: subprocess.CompletedProcess = self.lint({});
    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
    self.assertIn("lint_skills: OK", result.stdout);
}

impl LintSkillsTests.test_malformed_settings_fail_cleanly {
    for (text, message) in settings_cases() {
        with self.subTest(settings=text) {
            result: subprocess.CompletedProcess = self.lint({SETTINGS: text});
            self.assertEqual(result.returncode, 1);
            self.assertIn(message, result.stdout);
        }
    }
}

impl LintSkillsTests.test_skill_and_command_checks {
    missing: str = FRONTMATTER
        + "allowed-tools: Bash(bun run .claude/skills/example/DOES_NOT_EXIST.ts *)\n---\n";
    present: str = FRONTMATTER + f"allowed-tools: Bash(bun run {CLI} *)\n---\n";
    cases: list[tuple[dict[str, str], list[str]]] = [
        ({SKILL: missing}, ["allowed-tools references a missing file", "DOES_NOT_EXIST.ts"]),
        ({SKILL: present, CLI: "// present\n"}, []),
        (
            {SKILL: "---\nname: example\ndescription:\n---\n"},
            ["missing required key 'description'"],
        ),
        ({COMMAND: "# setup - missing the slash\n"}, ["must start with a '# /<name>' title"]),
    ];
    for (files, messages) in cases {
        with self.subTest(files=files) {
            result: subprocess.CompletedProcess = self.lint(files);
            self.assertEqual(result.returncode, 1 if messages else 0, result.stdout);
            for message in messages {
                self.assertIn(message, result.stdout);
            }
        }
    }
}
