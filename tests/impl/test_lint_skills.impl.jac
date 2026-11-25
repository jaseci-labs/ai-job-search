impl run_linter(`root: Path) -> subprocess.CompletedProcess {
    return subprocess.run([*tool("lint_skills")], capture_output=True, text=True);
}

impl LinterRepoFixture.setUp -> any {
    self.root = Path(tempfile.mkdtemp());
    self.addCleanup(shutil.rmtree, self.root, ignore_errors=True);

    tools: any = self.root / "tools";
    tools.mkdir();
    root_at(self, self.root);

    command: any = self.root / ".claude" / "commands" / "setup.md";
    command.parent.mkdir(parents=True);
    command.write_text("# /setup - Test setup command\n", encoding="utf-8");

    skill: any = self.root / ".claude" / "skills" / "example" / "SKILL.md";
    skill.parent.mkdir(parents=True);
    skill.write_text("---\nname: example\ndescription: Example skill\n---\n", encoding="utf-8");

    self.settings = self.root / ".claude" / "settings.json";
    self.write_settings({"permissions": {"allow": []}});
}

impl LinterRepoFixture.write_settings(data) -> any {
    self.settings.write_text(json.dumps(data), encoding="utf-8");
}

impl SettingsShapeTests.test_valid_settings_pass -> any {
    result: any = run_linter(self.root);

    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
    self.assertIn("lint_skills: OK", result.stdout);
}

impl SettingsShapeTests.test_invalid_json_fails_cleanly -> any {
    self.settings.write_text("{not json", encoding="utf-8");

    result: any = run_linter(self.root);

    self.assertEqual(result.returncode, 1);
    self.assertIn(".claude/settings.json", result.stdout);
    self.assertNotIn("Traceback", result.stderr);
}

impl SettingsShapeTests.test_non_object_root_fails_cleanly -> any {
    for data in ([], "settings", 1, None) {
        with self.subTest(data=data) {
            self.write_settings(data);

            result: any = run_linter(self.root);

            self.assertEqual(result.returncode, 1);
            self.assertIn("top-level JSON value to be an object", result.stdout);
            self.assertNotIn("Traceback", result.stderr);
        }
    }
}

impl SettingsShapeTests.test_non_object_permissions_fails_cleanly -> any {
    for permissions in ([], "permissions", 1, None) {
        with self.subTest(permissions=permissions) {
            self.write_settings({"permissions": permissions});

            result: any = run_linter(self.root);

            self.assertEqual(result.returncode, 1);
            self.assertIn("expected permissions to be an object", result.stdout);
            self.assertNotIn("Traceback", result.stderr);
        }
    }
}

impl SettingsShapeTests.test_non_list_allow_fails_cleanly -> any {
    for allow in ({}, "Bash(bun run:*)", 1, None) {
        with self.subTest(allow=allow) {
            self.write_settings({"permissions": {"allow": allow}});

            result: any = run_linter(self.root);

            self.assertEqual(result.returncode, 1);
            self.assertIn("expected permissions.allow to be a list", result.stdout);
            self.assertNotIn("Traceback", result.stderr);
        }
    }
}

impl SkillAndCommandCheckTests.write_skill(frontmatter: builtins.str) -> any {
    skill: any = self.root / ".claude" / "skills" / "example" / "SKILL.md";
    skill.write_text(frontmatter, encoding="utf-8");
}

impl SkillAndCommandCheckTests.test_allowed_tools_referencing_a_missing_file_fails -> any {
    self.write_skill(
        "---\nname: example\ndescription: Example skill\nallowed-tools: Bash(bun run .claude/skills/example/DOES_NOT_EXIST.ts *)\n---\n",
    );

    result: any = run_linter(self.root);

    self.assertEqual(result.returncode, 1, result.stdout + result.stderr);
    self.assertIn("allowed-tools references a missing file", result.stdout);
    self.assertIn("DOES_NOT_EXIST.ts", result.stdout);
}

impl SkillAndCommandCheckTests.test_allowed_tools_referencing_an_existing_file_passes -> any {
    target: any = self.root / ".claude" / "skills" / "example" / "cli.ts";
    target.write_text("// present\n", encoding="utf-8");
    self.write_skill(
        "---\nname: example\ndescription: Example skill\nallowed-tools: Bash(bun run .claude/skills/example/cli.ts *)\n---\n",
    );

    result: any = run_linter(self.root);

    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
}

impl SkillAndCommandCheckTests.test_frontmatter_missing_description_fails -> any {
    self.write_skill("---\nname: example\ndescription:\n---\n");

    result: any = run_linter(self.root);

    self.assertEqual(result.returncode, 1);
    self.assertIn("missing required key 'description'", result.stdout);
}

impl SkillAndCommandCheckTests.test_command_without_slash_title_fails -> any {
    command: any = self.root / ".claude" / "commands" / "setup.md";
    command.write_text("# setup - missing the slash\n", encoding="utf-8");

    result: any = run_linter(self.root);

    self.assertEqual(result.returncode, 1);
    self.assertIn("must start with a '# /<name>' title", result.stdout);
}
