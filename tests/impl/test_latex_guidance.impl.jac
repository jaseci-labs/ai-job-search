impl section(text, heading) -> any {
    pattern: any = re.compile(
        f"^#+ {re.escape(heading)}[^\\n]*\\n(.*?)(?=^#+ |\\Z)", re.MULTILINE | re.DOTALL
    );
    `match: any = pattern.search(text);
    return `match.group(1) if `match else None;
}

impl TestBulletBracketTrap.assert_no_unbraced_bracket_items(path) -> any {
    offending: any = [
        f"{path.name}:{lineno}: {line.strip()}"
        for (lineno, line) in enumerate(path.read_text(encoding="utf-8").splitlines(), 1)
        if UNBRACED_BRACKET_ITEM.search(line)
    ];
    self.assertEqual(
        offending,
        [],
        "\\item followed by [ is parsed as an optional label and the text is clipped off the page; write \\item {[...]} instead:\n"
            + "\n".join(offending),
    );
}

impl TestBulletBracketTrap.test_example_cv_has_no_bracket_labelled_bullets -> any {
    self.assert_no_unbraced_bracket_items(EXAMPLE_CV);
}

impl TestBulletBracketTrap.test_example_cover_letter_has_no_bracket_labelled_bullets -> any {
    self.assert_no_unbraced_bracket_items(EXAMPLE_COVER);
}

impl TestBulletBracketTrap.test_cover_letter_guide_does_not_teach_the_broken_pattern -> any {
    self.assert_no_unbraced_bracket_items(COVER_TEMPLATES);
}

impl TestBulletBracketTrap.test_cv_guide_does_not_teach_the_broken_pattern -> any {
    self.assert_no_unbraced_bracket_items(CV_TEMPLATES);
}

impl TestSpecialCharacterGuidance.assert_escapes_documented(path) -> any {
    body: any = section(path.read_text(encoding="utf-8"), "LaTeX Special Characters");
    self.assertIsNotNone(body, f"{path.name} has no 'LaTeX Special Characters' section");
    missing: any = [esc for esc in REQUIRED_ESCAPES if esc not in body];
    self.assertEqual(
        missing, [], f"{path.name}'s special-characters section is missing: {missing}"
    );
}

impl TestSpecialCharacterGuidance.test_cv_guide_documents_the_escapes -> any {
    self.assert_escapes_documented(CV_TEMPLATES);
}

impl TestSpecialCharacterGuidance.test_cover_letter_guide_documents_the_escapes -> any {
    self.assert_escapes_documented(COVER_TEMPLATES);
}

impl TestSpecialCharacterGuidance.test_cv_guide_warns_that_percent_truncates_silently -> any {
    body: any = section(CV_TEMPLATES.read_text(encoding="utf-8"), "LaTeX Special Characters");
    self.assertIsNotNone(body);
    self.assertRegex(
        body,
        re.compile("silent", re.IGNORECASE),
        "the % failure mode must be called out as silent - it is the reason this section exists (a clean compile with the rest of the bullet gone)",
    );
}

impl TestAtsExtractionEncoding.assert_pdftotext_commands_pin_utf8(path) -> any {
    offending: any = [
        f"{path.name}:{lineno}: {line.strip()}"
        for (lineno, line) in enumerate(path.read_text(encoding="utf-8").splitlines(), 1)
        if "pdftotext" in line and "-layout" in line and "-enc UTF-8" not in line
    ];
    self.assertEqual(
        offending,
        [],
        "pdftotext without -enc UTF-8 emits Latin-1 on Xpdf builds, so the ATS check reports phantom replacement characters on any non-ASCII CV; add -enc UTF-8:\n"
            + "\n".join(offending),
    );
}

impl TestAtsExtractionEncoding.test_apply_extraction_command_pins_utf8 -> any {
    self.assert_pdftotext_commands_pin_utf8(APPLY);
}

impl TestAtsExtractionEncoding.test_cv_guide_extraction_command_pins_utf8 -> any {
    self.assert_pdftotext_commands_pin_utf8(CV_TEMPLATES);
}

impl TestPdflatexFontEncodingGuard.assert_has_guarded_fontenc(path) -> any {
    text: any = path.read_text(encoding="utf-8");
    self.assertRegex(
        text,
        self.GUARDED_FONTENC,
        f"{path.name} must carry `\\ifpdftex\\usepackage[T1]{{fontenc}}\\fi` so a pdflatex fallback keeps accents precomposed in the text layer",
    );
    unguarded: any = [
        f"{path.name}:{lineno}: {line.strip()}"
        for (lineno, line) in enumerate(text.splitlines(), 1)
        if "fontenc" in line
            and not line.lstrip().startswith("%")
            and not self.GUARDED_FONTENC.search(line)
    ];
    self.assertEqual(
        unguarded,
        [],
        "fontenc must stay inside the \\ifpdftex guard - lualatex output must not change:\n"
            + "\n".join(unguarded),
    );
}

impl TestPdflatexFontEncodingGuard.test_example_cv_guards_fontenc_for_pdflatex -> any {
    self.assert_has_guarded_fontenc(EXAMPLE_CV);
}

impl TestPdflatexFontEncodingGuard.test_cv_guide_preamble_guards_fontenc_for_pdflatex -> any {
    self.assert_has_guarded_fontenc(CV_TEMPLATES);
}

impl TestMissingPackageGuidance.test_cv_guide_states_the_rule -> any {
    body: any = section(CV_TEMPLATES.read_text(encoding="utf-8"), self.HEADING);
    self.assertIsNotNone(body, f"05-cv-templates.md needs a '{self.HEADING}' section");
    self.assertIn("tlmgr search --global --file", body);
    self.assertIn(
        "never run `sudo`", body.lower(), "the rule must say what to do when an install needs root"
    );
}

impl TestMissingPackageGuidance.test_every_compile_loop_points_to_the_rule -> any {
    add_template: any = REPO / ".claude" / "commands" / "add-template.md";
    for path in (COVER_TEMPLATES, APPLY, add_template) {
        with self.subTest(path=path.name) {
            self.assertIn(self.HEADING, path.read_text(encoding="utf-8"));
        }
    }
}

impl TestGeometryScaleAlignment.test_cv_guide_and_example_cv_share_geometry_scale -> any {
    cv_match: any = self.GEOMETRY_SCALE.search(EXAMPLE_CV.read_text(encoding="utf-8"));
    guide_match: any = self.GEOMETRY_SCALE.search(CV_TEMPLATES.read_text(encoding="utf-8"));
    self.assertIsNotNone(cv_match, "cv/main_example.tex must declare geometry scale");
    self.assertIsNotNone(guide_match, "05-cv-templates.md must declare geometry scale");
    self.assertEqual(
        guide_match.group(1),
        cv_match.group(1),
        f"05-cv-templates.md geometry scale ({guide_match.group(1)}) must match cv/main_example.tex ({cv_match.group(1)})",
    );
}
