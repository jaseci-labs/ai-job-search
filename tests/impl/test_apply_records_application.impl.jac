impl derive(company: str, role: str) -> str | None {
    name: str = re.sub("[^\\w]", "", f"{company}_{role}".lower().replace(" ", "_"));
    return re.sub("_+", "_", name).strip("_") or None;
}

impl cv_glob(rel: str, heading: str) -> str {
    found: list[str] = re.findall(
        "`(cv/main_[^`]+|cover_letters/cover_[^`]+)`", section(doc(rel), heading)
    );
    return [g for g in found if "*" in g and g.startswith("cv/")][0];
}

impl resolve(pattern: str, role: str) -> str {
    return pattern.replace("<company>_<role>", derive(COMPANY, role) or "").replace(
        "<company>", (derive(COMPANY, "") or "").rstrip("_")
    );
}

impl drafted_files(ext: str = ".tex") -> list[str] {
    return [f"cv/main_{derive(COMPANY, r)}{ext}" for r in ROLES];
}

impl ApplyRecordsApplication.test_every_file_states_its_rules {
    for (theme, cases) in RULES.items() {
        with self.subTest(theme=theme) {
            expect_all(self, cases);
        }
    }
}

impl ApplyRecordsApplication.test_tracker_header_is_the_same_line_in_both_commands_and_ends_with_deadline {
    self.assertTrue(TRACKER_HEADER.endswith(",deadline"));
    for text in (doc(OUTCOME), section(doc(APPLY), STEP_6B)) {
        headers: list[str] = [
            ln.strip()
            for ln in text.splitlines()
            if ln.strip().startswith("date,company,")
        ];
        self.assertEqual(headers[:1], [TRACKER_HEADER]);
    }
}

impl ApplyRecordsApplication.test_migration_appends_the_headers_own_last_column {
    last_column: str = TRACKER_HEADER.rsplit(",", 1)[1];
    for (rel, heading) in ((APPLY, STEP_6B), (OUTCOME, OUTCOME_1)) {
        expect(self, section(doc(rel), heading), f"append `,{last_column}` to the header line");
    }
}

impl ApplyRecordsApplication.test_step_runs_before_the_optional_offer_that_ends_the_turn {
    text: str = doc(APPLY);
    self.assertLess(text.index(STEP_6B), text.index("### Application-Form Fields"));
}

impl ApplyRecordsApplication.test_lint_skills_passes {
    lint_skills_passes(self);
}

impl ApplyRecordsApplication.test_the_cv_glob_selects_the_row_s_own_role {
    on_disk: list[str] = drafted_files();
    for (rel, heading) in ((OUTCOME, OUTCOME_3), (INTERVIEW, INTERVIEW_1)) {
        pattern: str = cv_glob(rel, heading);
        for (role, expected) in zip(ROLES, on_disk) {
            with self.subTest(file=rel, role=role) {
                self.assertEqual(fnmatch.filter(on_disk, resolve(pattern, role)), [expected]);
            }
        }
    }
}

impl ApplyRecordsApplication.test_the_glob_finds_a_non_tex_template {
    on_disk: list[str] = drafted_files(".typ");
    pattern: str = resolve(cv_glob(OUTCOME, OUTCOME_3), ROLES[0]);
    self.assertEqual(fnmatch.filter(on_disk, pattern), [on_disk[0]]);
}

impl ApplyRecordsApplication.test_archiving_keeps_each_submitted_sources_extension_and_bytes {
    targets: re.Match | None = re.search(
        "\\*\\*`(cv_draft[^`]+)` and `(cover_letter[^`]+)`\\*\\*", section(doc(OUTCOME), OUTCOME_3)
    );
    assert targets is not None, "the archive must name both destination sources";
    for (ext, content) in (
        (".tex", b"\\documentclass{article}\n"),
        (".typ", b"#set text(size: 11pt)\n"),
    ) {
        for (directory, stem, target) in (
            ("cv", "main", targets.group(1)),
            ("cover_letters", "cover", targets.group(2)),
        ) {
            with self.subTest(ext=ext, document=directory), tempfile.TemporaryDirectory() as tmp {
                source: Path = Path(tmp) / directory / f"{stem}_acme_ml-engineer{ext}";
                source.parent.mkdir();
                source.write_bytes(content);
                destination: Path = Path(tmp)
                    / target.replace("<CV_EXT>", ext).replace("<COVER_EXT>", ext);
                shutil.copyfile(source, destination);
                self.assertEqual(destination.suffix, source.suffix);
                self.assertEqual(destination.read_bytes(), content);
            }
        }
    }
}

impl ApplyRecordsApplication.test_documented_rule_yields_a_single_path_component {
    cases: list[tuple[str, str, str | None]] = [
        ("Novo Nordisk A/S", "Data Scientist", "novo_nordisk_as_data_scientist"),
        ("Acme", "Data Scientist / ML Engineer", "acme_data_scientist_ml_engineer"),
        ("Ørsted A/S", "ML Engineer", "ørsted_as_ml_engineer"),
        ("../..", "Data Scientist", "data_scientist"),
        ("../..", "///", None),
    ];
    for (company, role, expected) in cases {
        with self.subTest(company=company, role=role) {
            self.assertEqual(derive(company, role), expected);
        }
    }
}
