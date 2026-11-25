impl TestOnboardingPrivacy.test_fork_sections_warn_next_to_the_fork_command {
    for (rel, level, heading) in (
        ("README.md", "###", "1. Fork and clone"),
        ("SETUP.md", "##", "2. Fork and clone"),
    ) {
        with self.subTest(file=rel) {
            body: str = parts(doc(rel), level).get(heading, "");
            check(self, body, ["gh repo fork", "personal data"]);
            self.assertRegex(body, re.compile("public", re.IGNORECASE));
            self.assertRegex(body, re.compile("section 8|§8|#8-pulling", re.IGNORECASE));
        }
    }
}

impl TestOnboardingPrivacy.test_setup_preflight_exists_and_precedes_profile_generation {
    text: str = command("setup");
    self.assertIn("git remote get-url origin", text);
    preflight_at: int = text.index("git remote get-url origin");
    self.assertLess(preflight_at, text.index("## Step 3: Generate Profile Files"));
    self.assertIn("public", text[max(0, preflight_at - 2000):preflight_at + 2000].lower());
}
