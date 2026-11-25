impl ExpandCommandTests.test_expand_command_file_exists -> any {
    self.assertTrue(EXPAND_COMMAND_FILE.exists(), "expand.md must exist under .claude/commands/");
}

impl ExpandCommandTests.test_expand_command_file_starts_with_correct_header -> any {
    text: any = EXPAND_COMMAND_FILE.read_text(encoding="utf-8");
    first_line: any = text.lstrip().splitlines()[0];
    self.assertTrue(
        first_line.startswith("# /expand"),
        f"Command file must start with '# /expand', got: {first_line!r}",
    );
}

impl ExpandCommandTests.test_expand_covers_all_discovery_sources -> any {
    text: any = EXPAND_COMMAND_FILE.read_text(encoding="utf-8");
    sources: any = [
        "documents/cv/",
        "documents/linkedin/",
        "documents/diplomas/",
        "documents/references/",
        "GitHub Profile",
    ];
    for src in sources {
        self.assertIn(src, text, f"expand.md must include discovery source: {src}");
    }
}

impl ExpandCommandTests.test_expand_maps_github_projects_to_independent_projects_section -> any {
    text: any = EXPAND_COMMAND_FILE.read_text(encoding="utf-8");
    self.assertIn("## Independent Projects", text);
    self.assertIn("Independent Projects & Portfolio", text);
    self.assertIn("GitHub — repo-name", text);
    self.assertIn("Portfolio & projects grounded in code", text);
    self.assertNotIn("documents/projects/", text);
}

impl ExpandCommandTests.test_behavioral_additions_name_sections_the_shipped_file_has -> any {
    text: any = EXPAND_COMMAND_FILE.read_text(encoding="utf-8");
    start: any = text.index("### Additions to `02-behavioral-profile.md`");
    section: any = text[start:text.index("---", start)];
    quoted: any = re.findall("\"([^\"]+)\"", section);
    self.assertTrue(quoted, "the 02-behavioral-profile step must name its target sections");
    headings: any = {
        line[3:].strip()
        for line in BEHAVIORAL_PROFILE.read_text(encoding="utf-8").splitlines()
        if line.startswith("## ")
    };
    for name in quoted {
        with self.subTest(section=name) {
            self.assertIn(name, headings, f"02-behavioral-profile.md has no '## {name}' heading");
        }
    }
}

impl ExpandCommandTests.test_expand_enforces_additive_and_confirmation_principles -> any {
    text: any = EXPAND_COMMAND_FILE.read_text(encoding="utf-8");
    self.assertIn("Additive only", text);
    self.assertIn("User confirms before writing", text);
    self.assertIn("`all`", text);
    self.assertIn("`review`", text);
    self.assertIn("`skip`", text);
}
