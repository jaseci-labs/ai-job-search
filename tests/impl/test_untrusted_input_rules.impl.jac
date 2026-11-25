impl ingesting_specs -> dict[str, str] {
    paths: list[Path] = sorted(COMMANDS.glob("*.md"))
        + sorted((REPO / ".claude" / "skills").glob("*/SKILL.md"));
    texts: dict[str, str] = {
        path.relative_to(REPO).as_posix(): path.read_text(encoding="utf-8")
        for path in paths
    };
    return {name: text for (name, text) in texts.items() if INGESTS.search(text)};
}

impl TrustBoundaryTests.test_derived_set_is_not_empty {
    for anchor in (
        ".claude/commands/gmail-sync.md",
        ".claude/commands/setup.md",
        ".claude/skills/job-scraper/SKILL.md",
    ) {
        self.assertIn(anchor, ingesting_specs());
    }
}

impl TrustBoundaryTests.test_every_ingesting_spec_states_the_rule {
    missing: list[str] = [
        name
        for (name, text) in ingesting_specs().items()
        if not RULE.search(text)
    ];
    self.assertEqual(missing, [], "these specs read third-party content without the trust rule");
}

impl TrustBoundaryTests.test_gmail_sync_never_acts_on_email_content {
    text: str = (COMMANDS / "gmail-sync.md").read_text(encoding="utf-8");
    rules: str = text[text.index("## Important Rules"):];
    self.assertTrue(RULE.search(rules), "Important Rules must state that email is untrusted");
    for phrase in (
        "no link is fetched",
        "no attachment is opened",
        "no reply, draft, label or forward",
    ) {
        self.assertIn(phrase, rules);
    }
}

impl TrustBoundaryTests.test_setup_calibration_never_copies_archive_wording {
    text: str = (COMMANDS / "setup.md").read_text(encoding="utf-8");
    step: str = text[text.index("### Step A3"):text.index("### Step A4")];
    self.assertTrue(
        RULE.search(step), "Step A3 must mark job_posting.md and outcome.md as untrusted"
    );
    self.assertIn("never copy their wording into CLAUDE.md or a skill file", step);
}
