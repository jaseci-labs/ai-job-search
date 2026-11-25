impl TestSetupCommand.test_step3_template_substeps_fill_the_contact_blocks {
    substeps: dict[str, str] = parts(
        parts(command("setup"), "##")["Step 3: Generate Profile Files"], "###"
    );
    for (filename, word, tokens) in (
        ("05-cv-templates.md", "contact", CV_TOKENS),
        ("06-cover-letter-templates.md", "signature", COVER_TOKENS),
    ) {
        with self.subTest(file=filename) {
            bodies: list[str] = [
                body
                for (heading, body) in substeps.items()
                if filename in heading
            ];
            self.assertEqual(len(bodies), 1, "expected exactly one Step 3 substep");
            self.assertIn(word, bodies[0].lower());
            check(self, bodies[0], tokens);
        }
    }
}

impl TestSetupCommand.test_completion_summary_lists_the_cover_letter_templates {
    step4: str = parts(command("setup"), "##")["Step 4: Confirm & Next Steps"];
    self.assertIn("06-cover-letter-templates.md", step4.split("**Privacy note:**")[0]);
}

impl TestSetupCommand.test_templates_still_carry_the_placeholders {
    check(self, skill("05-cv-templates.md"), [*CV_TOKENS, "[LAST_NAME]"]);
    check(self, skill("06-cover-letter-templates.md"), [*COVER_TOKENS, "\\signature{[YOUR_NAME]}"]);
}

impl TestSetupCommand.test_behavioral_profile_bullet_names_real_headings {
    names: list[str] = quoted(
        [
            line
            for line in command("setup").splitlines()
            if line.startswith("- **`02-behavioral-profile.md`:**")
        ][0],
    );
    self.assertTrue(names, "the 02-behavioral-profile bullet must name its target sections");
    for name in names {
        with self.subTest(section=name) {
            self.assertIn(name, h2(skill("02-behavioral-profile.md")));
        }
    }
}

impl TestSetupCommand.test_path_a_ingests_projects {
    text: str = command("setup");
    self.assertIn("projects/", parts(text, "##")["Step 0: Welcome & Choose Path"]);
    check(
        self,
        text,
        [
            "**projects/**:",
            "`projects/` documents:",
            "measurable outcomes",
            "## Independent Projects",
            "New independent project:",
        ],
    );
}
