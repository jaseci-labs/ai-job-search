impl personalize_cv(text: builtins.str) -> builtins.str {
    return text.replace("\\name{[First]}{[Last]}", "\\name{Jane}{Doe}").replace(
        "[Your Address, City, Country]", "Some Street 1, Aarhus, Denmark"
    ).replace("[+XX XXXXXXXXXX]", "+45 12345678").replace(
        "[your.email@example.com]", "jane.doe@example.org"
    );
}

impl TestCvSentinelsAreDataLocated.setUp -> any {
    self.ci = CI.read_text(encoding="utf-8");
    self.cv = EXAMPLE_CV.read_text(encoding="utf-8");
}

impl TestCvSentinelsAreDataLocated.test_ci_checks_the_name_and_email_data_lines -> any {
    self.assertIn(
        "check cv/main_example.tex '\\\\name{\\[First\\]}{\\[Last\\]}'",
        self.ci,
        "ci.yml must assert the sentinel inside the \\name{} data line",
    );
    self.assertIn(
        "check cv/main_example.tex '\\\\email{\\[your\\.email@example\\.com\\]}'",
        self.ci,
        "ci.yml must assert the sentinel inside the \\email{} data line",
    );
}

impl TestCvSentinelsAreDataLocated.test_pristine_cv_carries_both_sentinels -> any {
    for sentinel in CV_SENTINELS {
        self.assertIn(sentinel, self.cv);
    }
}

impl TestCvSentinelsAreDataLocated.test_setup_edit_destroys_the_sentinels -> any {
    personalized: any = personalize_cv(self.cv);
    self.assertNotEqual(personalized, self.cv, "the simulated /setup edit must change the file");
    surviving: any = [s for s in CV_SENTINELS if s in personalized];
    self.assertEqual(
        surviving,
        [],
        f"a sentinel survived the documented /setup personalization - the guard would pass on committed personal data: {surviving}",
    );
}

impl TestProfileSentinelIsDataLocated.test_ci_checks_a_data_placeholder_not_the_header_comment -> any {
    ci: any = CI.read_text(encoding="utf-8");
    self.assertIn(
        "check .claude/skills/job-application-assistant/01-candidate-profile.md '\\[YOUR_EMAIL\\]'",
        ci,
        "01's sentinel must sit in the Identity data /setup fills, not in a header comment the model may leave untouched",
    );
}

impl TestProfileSentinelIsDataLocated.test_pristine_profile_carries_the_sentinel -> any {
    self.assertIn(PROFILE_SENTINEL, PROFILE.read_text(encoding="utf-8"));
}
