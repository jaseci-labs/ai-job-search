impl ArchiveWiring.setUp -> any {
    text: any = APPLY.read_text(encoding="utf-8");
    self.step6b = re.search(
        "### Step 6b: Record the Application(.*?)(?=### Application-Form Fields)", text, re.DOTALL
    ).group(1);
}

impl ArchiveWiring.test_archive_stores_cleaned_text_with_counts_only -> any {
    item7: any = re.search(
        "7\\. \\*\\*Archive the posting now\\.\\*\\*(.*?)(?=\\n\\n|\\Z)", self.step6b, re.DOTALL
    ).group(1);
    self.assertIn("verbatim", item7);
    self.assertIn("posting_guard", item7);
    self.assertIn("counts", item7);
    self.assertRegex(item7, "never .*excerpt", "removed content must not be re-archived as quotes");
}

impl InterviewWiring.test_step1_gates_the_archived_posting_in_text_mode -> any {
    text: any = INTERVIEW.read_text(encoding="utf-8");
    step1: any = re.search(
        "## Step 1: Load the Application Context(.*?)(?=\\n## Step 2)", text, re.DOTALL
    ).group(1);
    self.assertIn("posting_guard", step1);
    self.assertIn("--text", step1);
}

impl OtherFrontDoors.test_skill_step1_names_the_gate -> any {
    text: any = (REPO / ".claude" / "skills" / "job-application-assistant" / "SKILL.md").read_text(
        encoding="utf-8"
    );
    step1: any = re.search(
        "### Step 1: Research & Evaluate Fit(.*?)(?=### Step 2)", text, re.DOTALL
    ).group(1);
    self.assertIn("posting_guard", step1);
    version: any = re.search("^framework_version: (\\d+)\\.(\\d+)\\.(\\d+)$", text, re.MULTILINE);
    self.assertIsNotNone(version);
    self.assertGreaterEqual(`tuple(`int(part) for part in version.groups()), (1, 3, 6));
}

impl OtherFrontDoors.test_outcome_fresh_fetch_is_gated -> any {
    text: any = (REPO / ".claude" / "commands" / "outcome.md").read_text(encoding="utf-8");
    self.assertIn("posting_guard", text);
}

impl OtherFrontDoors.test_interview_fetch_fallback_is_gated -> any {
    text: any = INTERVIEW.read_text(encoding="utf-8");
    step1: any = re.search(
        "## Step 1: Load the Application Context(.*?)(?=\\n## Step 2)", text, re.DOTALL
    ).group(1);
    fallback: any = re.search(
        "2\\. \\*\\*Fallbacks\\*\\*(.*?)(?=\\n3\\. )", step1, re.DOTALL
    ).group(1);
    self.assertIn("posting_guard", fallback);
}

impl OtherFrontDoors.test_scratchpad_is_guarded_everywhere_the_gate_writes -> any {
    for path in (
        APPLY,
        REPO / ".claude" / "agents" / "posting-fetcher.md",
        REPO / ".claude" / "agents" / "posting-scorer.md",
    ) {
        text: any = path.read_text(encoding="utf-8");
        with self.subTest(path=path.name) {
            self.assertNotRegex(
                text, "\\$SCRATCHPAD/", "use ${SCRATCHPAD:?...} so an unset variable fails loudly"
            );
            self.assertIn("${SCRATCHPAD:?", text);
        }
    }
}

impl OtherFrontDoors.test_fetch_agents_can_discover_installed_portals -> any {
    for name in ("posting-fetcher.md", "posting-scorer.md") {
        text: any = (REPO / ".claude" / "agents" / name).read_text(encoding="utf-8");
        tools: any = re.search("^tools:\\s*(.*)$", text, re.M).group(1);
        with self.subTest(agent=name) {
            self.assertIn("Glob", tools, "rung 1 needs to find .agents/skills/*/SKILL.md");
        }
    }
}

impl TrustBoundaryWiring.test_09_trust_boundary_names_the_gate -> any {
    text: any = RESEARCH.read_text(encoding="utf-8");
    boundary: any = re.search("## Trust boundary(.*?)(?=\\n## )", text, re.DOTALL).group(1);
    self.assertIn("posting_guard", boundary);
    self.assertIn("framework_version: 1.2.0", text);
}
