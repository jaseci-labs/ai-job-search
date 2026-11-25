impl _sections(text: builtins.str) -> builtins.dict[builtins.str, builtins.str] {
    parts: any = text.split("\n## ");
    result: any = {};
    for part in parts[1:] {
        heading: any;
        _: any;
        body: any;
        (heading, _, body) = part.partition("\n") as any;
        result[heading.strip()] = body;
    }
    return result;
}

impl _substeps(step_body: builtins.str) -> builtins.dict[builtins.str, builtins.str] {
    parts: any = step_body.split("\n### ");
    result: any = {};
    for part in parts[1:] {
        heading: any;
        _: any;
        body: any;
        (heading, _, body) = part.partition("\n") as any;
        result[heading.strip()] = body;
    }
    return result;
}

impl SetupStep3ContactBlocks.setUp -> any {
    self.step3 = _sections(COMMAND.read_text(encoding="utf-8"))["Step 3: Generate Profile Files"];
    self.substeps = _substeps(self.step3);
}

impl SetupStep3ContactBlocks._substep_for(filename: builtins.str) -> builtins.str {
    matches: any = [body for (heading, body) in self.substeps.items() if filename in heading];
    self.assertEqual(
        len(matches), 1, f"expected exactly one Step 3 substep for {filename}, got {len(matches)}"
    );
    return matches[0];
}

impl SetupStep3ContactBlocks.test_cv_templates_substep_fills_the_contact_block -> any {
    body: any = self._substep_for("05-cv-templates.md");
    self.assertIn("contact", body.lower());
    for token in ("[FIRST_NAME]", "[YOUR_EMAIL]", "[YOUR_PHONE]") {
        self.assertIn(token, body, f"the 05 substep must name {token} as something to replace");
    }
}

impl SetupStep3ContactBlocks.test_cover_letter_templates_get_their_own_substep -> any {
    body: any = self._substep_for("06-cover-letter-templates.md");
    self.assertIn("signature", body.lower());
    for token in ("[YOUR_NAME]", "[YOUR_EMAIL]", "[YOUR_PHONE]", "[YOUR_LINKEDIN_URL]") {
        self.assertIn(token, body, f"the 06 substep must name {token} as something to replace");
    }
}

impl SetupStep3ContactBlocks.test_completion_summary_lists_the_cover_letter_templates -> any {
    step4: any = _sections(COMMAND.read_text(encoding="utf-8"))["Step 4: Confirm & Next Steps"];
    summary: any = step4.split("**Privacy note:**")[0];
    self.assertIn("06-cover-letter-templates.md", summary);
}

impl TemplatesStillCarryThePlaceholders.test_cv_templates_contact_block_tokens -> any {
    text: any = CV_TEMPLATES.read_text(encoding="utf-8");
    for token in ("[FIRST_NAME]", "[LAST_NAME]", "[YOUR_EMAIL]", "[YOUR_PHONE]") {
        self.assertIn(token, text);
    }
}

impl TemplatesStillCarryThePlaceholders.test_cover_letter_templates_contact_and_signature_tokens -> any {
    text: any = COVER_TEMPLATES.read_text(encoding="utf-8");
    for token in ("[YOUR_NAME]", "[YOUR_EMAIL]", "[YOUR_PHONE]", "[YOUR_LINKEDIN_URL]") {
        self.assertIn(token, text);
    }
    self.assertIn("\\signature{[YOUR_NAME]}", text);
}

impl SetupPathAWritesIntoSectionsTheShippedFilesHave.test_behavioral_profile_bullet_names_real_headings -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    bullet: any = next(
        line for line in text.splitlines() if line.startswith("- **`02-behavioral-profile.md`:**")
    );
    quoted: any = re.findall("\"([^\"]+)\"", bullet);
    self.assertTrue(quoted, "the 02-behavioral-profile bullet must name its target sections");
    headings: any = {
        line[3:].strip()
        for line in (SKILL_DIR / "02-behavioral-profile.md").read_text(
            encoding="utf-8"
        ).splitlines()
        if line.startswith("## ")
    };
    for name in quoted {
        with self.subTest(section=name) {
            self.assertIn(name, headings, f"02-behavioral-profile.md has no '## {name}' heading");
        }
    }
}

impl SetupPathAProjectsIngestion.setUp -> any {
    self.text = COMMAND.read_text(encoding="utf-8");
    self.sections = _sections(self.text);
}

impl SetupPathAProjectsIngestion.test_step0_scan_includes_projects -> any {
    step0: any = self.sections["Step 0: Welcome & Choose Path"];
    self.assertIn("projects/", step0);
}

impl SetupPathAProjectsIngestion.test_step_a1_inventory_includes_projects -> any {
    self.assertIn("**projects/**:", self.text);
}

impl SetupPathAProjectsIngestion.test_step_a3_parsing_includes_projects_spec -> any {
    self.assertIn("`projects/` documents:", self.text);
    self.assertIn("measurable outcomes", self.text);
}

impl SetupPathAProjectsIngestion.test_step_a5_and_a6_map_to_independent_projects -> any {
    self.assertIn("## Independent Projects", self.text);
    self.assertIn("New independent project:", self.text);
}
