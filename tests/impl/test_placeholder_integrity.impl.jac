impl TestSentinelsAreDataLocated.test_ci_checks_the_data_lines {
    check(
        self,
        doc(".github/workflows/ci.yml"),
        [
            "check cv/main_example.tex '\\\\name{\\[First\\]}{\\[Last\\]}'",
            "check cv/main_example.tex '\\\\email{\\[your\\.email@example\\.com\\]}'",
            "check .claude/skills/job-application-assistant/01-candidate-profile.md '\\[YOUR_EMAIL\\]'",
        ],
    );
}

impl TestSentinelsAreDataLocated.test_pristine_files_carry_the_sentinels {
    check(self, doc("cv/main_example.tex"), CV_SENTINELS);
    self.assertIn("[YOUR_EMAIL]", skill("01-candidate-profile.md"));
}

impl TestSentinelsAreDataLocated.test_setup_edit_destroys_the_cv_sentinels {
    pristine: str = doc("cv/main_example.tex");
    personalized: str = pristine;
    for (placeholder, value) in PERSONALIZED.items() {
        personalized = personalized.replace(placeholder, value);
    }
    self.assertNotEqual(personalized, pristine, "the simulated /setup edit must change the file");
    self.assertEqual([s for s in CV_SENTINELS if s in personalized], []);
}
