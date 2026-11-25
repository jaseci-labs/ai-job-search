impl section(path, heading) -> any {
    text: any = path.read_text(encoding="utf-8");
    start: any = text.index(heading) + len(heading);
    rest: any = text[start:];
    end: any = re.search("^#{1,4} ", rest, re.MULTILINE);
    return rest[:end.start()] if end else rest;
}

impl ApplyRecordsApplication.setUp -> any {
    self.step_6b = section(APPLY, "### Step 6b: Record the Application");
}

impl ApplyRecordsApplication.test_step_writes_a_drafted_row_with_both_document_paths -> any {
    for fragment in (
        "| `status` | `drafted` |",
        "| `cv_file`, `cover_letter_file` | the two paths listed under \"Files Created\"",
    ) {
        self.assertIn(
            fragment,
            self.step_6b,
            f"Step 6b's column table lost {fragment!r} - the row it writes would no longer identify itself as a draft or point at the documents",
        );
    }
}

impl ApplyRecordsApplication.test_tracker_header_matches_outcome -> any {
    self.assertIn(TRACKER_HEADER, OUTCOME.read_text(encoding="utf-8"));
    self.assertIn(
        TRACKER_HEADER,
        self.step_6b,
        "Step 6b's header drifted from outcome.md's - whichever command ran first would decide the schema",
    );
    for (name, text) in (
        ("outcome.md", OUTCOME.read_text(encoding="utf-8")),
        ("apply.md Step 6b", self.step_6b),
    ) {
        header: any = next(
            (ln.strip() for ln in text.splitlines() if ln.strip().startswith("date,company,")), None
        );
        self.assertEqual(
            header,
            TRACKER_HEADER,
            f"{name}'s header line is not exactly the canonical header - a column appended to one file and not the other leaves both containing the shorter header as a substring, which assertIn alone cannot catch",
        );
    }
}

impl ApplyRecordsApplication.test_tracker_header_ends_with_deadline -> any {
    self.assertTrue(
        TRACKER_HEADER.endswith(",deadline"),
        "deadline must be the last column - a mid-header insert shifts every existing row's values by one position",
    );
}

impl ApplyRecordsApplication.test_migration_appends_the_headers_own_last_column -> any {
    last_column: any = TRACKER_HEADER.rsplit(",", 1)[1];
    outcome_step_1: any = section(OUTCOME, "## Step 1: Load State and Identify the Application");
    for (name, text) in (
        ("apply.md Step 6b", section(APPLY, "### Step 6b: Record the Application")),
        ("outcome.md Step 1", outcome_step_1),
    ) {
        self.assertIn(
            f"append `,{last_column}` to the header line",
            text,
            f"{name}'s migration does not append the header's own last column ({last_column!r}) - a tracker migrated by this command would not match one this command creates from scratch",
        );
    }
}

impl ApplyRecordsApplication.test_step_runs_before_the_optional_offer_that_ends_the_turn -> any {
    text: any = APPLY.read_text(encoding="utf-8");
    self.assertLess(
        text.index("### Step 6b: Record the Application"),
        text.index("### Application-Form Fields"),
        "Step 6b moved after the optional-artifact offer, which ends the turn on a question - the tracker row would be skipped whenever the user never answers",
    );
}

impl ApplyRecordsApplication.test_matched_row_is_never_moved_backwards -> any {
    self.assertIn(
        "never move it backwards",
        self.step_6b,
        "Step 6b lost the rule protecting a submitted row - re-running /apply to refresh a CV would reset a live interview back to drafted",
    );
}

impl ApplyRecordsApplication.test_redraft_marker_is_undated -> any {
    self.assertIn(
        "undated `redrafted` marker",
        self.step_6b,
        "a dated redraft marker resets /outcome's days-quiet clock, hiding a genuinely quiet application from the follow-up offer",
    );
}

impl ApplyRecordsApplication.test_seen_jobs_is_left_alone -> any {
    self.assertIn(
        "Do not modify `job_scraper/seen_jobs.json`",
        self.step_6b,
        "drafting is not applying, and that file has no honest value for either",
    );
}

impl ApplyRecordsApplication.test_skill_defers_to_apply_rather_than_restating -> any {
    step_3b: any = section(SKILL, "### Step 3b: Record the Application");
    self.assertIn(
        "`/apply` Step 6b",
        step_3b,
        "the skill's recording step no longer points at the canonical rule, so the two copies can drift",
    );
}

impl DraftedMeansDraftedToEveryReader.test_every_reader_handles_drafted -> any {
    for (path, heading, needle, why) in self.CASES {
        with self.subTest(file=path.name, rule=needle) {
            haystack: any = section(path, heading) if heading else path.read_text(encoding="utf-8");
            self.assertIn(needle, haystack, why);
        }
    }
}

impl DraftedMeansDraftedToEveryReader.test_lint_skills_passes -> any {
    result: any = subprocess.run([*tool("lint_skills")], cwd=REPO, capture_output=True, text=True);
    self.assertEqual(
        result.returncode, 0, f"lint_skills.jac failed:\n{result.stdout}{result.stderr}"
    );
}

impl ApplyArchivesThePosting.test_posting_is_archived_where_every_reader_looks -> any {
    for (path, heading, needle, why) in self.CASES {
        with self.subTest(file=path.name, rule=needle) {
            self.assertIn(needle, section(path, heading), why);
        }
    }
}

impl DeadlineSurvivesEveryWrite.test_deadline_survives_every_write -> any {
    for (path, heading, needle, why) in self.CASES {
        with self.subTest(file=path.name, rule=needle) {
            haystack: any = section(path, heading) if heading else path.read_text(encoding="utf-8");
            self.assertIn(needle, haystack, why);
        }
    }
}

impl FallbackGlobFindsOneRolesDocuments.test_both_readers_glob_the_full_stem -> any {
    for (path, heading, needle, why) in self.CASES {
        with self.subTest(file=path.name, rule=needle) {
            self.assertIn(needle, section(path, heading), why);
        }
    }
}

impl FallbackGlobFindsOneRolesDocuments.globs(path, heading) -> any {
    body: any = section(path, heading);
    found: any = re.findall("`(cv/main_[^`]+|cover_letters/cover_[^`]+)`", body);
    return [g for g in found if "*" in g];
}

impl FallbackGlobFindsOneRolesDocuments.resolve(`glob, role) -> any {
    stem: any = ArchiveNameIsOnePathComponent.derive(self.COMPANY, role);
    company: any = ArchiveNameIsOnePathComponent.derive(self.COMPANY, "").rstrip("_");
    return `glob.replace("<company>_<role>", stem).replace("<company>", company);
}

impl FallbackGlobFindsOneRolesDocuments.drafted_files(ext=".tex") -> any {
    return [
        "cv/main_%s%s" % (ArchiveNameIsOnePathComponent.derive(self.COMPANY, r), ext)
        for r in self.ROLES
    ];
}

impl FallbackGlobFindsOneRolesDocuments.test_the_cv_glob_selects_the_row_s_own_role -> any {
    on_disk: any = self.drafted_files();
    for (path, heading) in (
        (OUTCOME, "## Step 3: Archive the Application Materials"),
        (INTERVIEW, "## Step 1: Load the Application Context"),
    ) {
        cv_glob: any = next(g for g in self.globs(path, heading) if g.startswith("cv/"));
        for (role, expected) in zip(self.ROLES, on_disk) {
            with self.subTest(file=path.name, role=role) {
                hits: any = fnmatch.filter(on_disk, self.resolve(cv_glob, role));
                self.assertEqual(
                    hits,
                    [expected],
                    "%s's fallback glob %r matched %r for role %r. A glob that matches both roles hands /outcome whichever the filesystem returns first, and it archives that as what was submitted."
                        % (path.name, cv_glob, hits, role),
                );
            }
        }
    }
}

impl FallbackGlobFindsOneRolesDocuments.test_archiving_keeps_each_submitted_sources_extension_and_bytes -> any {
    body: any = section(OUTCOME, "## Step 3: Archive the Application Materials");
    destinations: any = re.search("\\*\\*`(cv_draft[^`]+)` and `(cover_letter[^`]+)`\\*\\*", body);
    self.assertIsNotNone(destinations, "the archive must name both destination sources");
    for (extension, content) in (
        (".tex", b"\\documentclass{article}\n"),
        (".typ", b"#set text(size: 11pt)\n"),
    ) {
        for (directory, stem, target) in (
            ("cv", "main", destinations.group(1)),
            ("cover_letters", "cover", destinations.group(2)),
        ) {
            tmp: any;
            with self.subTest(
                extension=extension, document=directory
            ), tempfile.TemporaryDirectory() as tmp {
                `root: any = Path(tmp);
                source: any = `root / directory / (stem + "_acme_ml-engineer" + extension);
                source.parent.mkdir();
                source.write_bytes(content);
                destination: any = `root
                    / target.replace("<CV_EXT>", extension).replace("<COVER_EXT>", extension);
                shutil.copyfile(source, destination);
                self.assertEqual(
                    destination.suffix,
                    source.suffix,
                    "archiving must preserve the submitted template's actual format",
                );
                self.assertEqual(destination.read_bytes(), source.read_bytes());
            }
        }
    }
}

impl FallbackGlobFindsOneRolesDocuments.test_the_glob_finds_a_non_tex_template -> any {
    on_disk: any = self.drafted_files(ext=".typ");
    cv_glob: any = next(
        g
        for g in self.globs(OUTCOME, "## Step 3: Archive the Application Materials")
        if g.startswith("cv/"),
    );
    hits: any = fnmatch.filter(on_disk, self.resolve(cv_glob, self.ROLES[0]));
    self.assertEqual(
        hits,
        [on_disk[0]],
        "the fallback hardcodes an extension, so a template registered by /add-template is invisible to it and /outcome archives nothing",
    );
}

impl ArchiveNameIsOnePathComponent.test_the_rule_has_one_home_and_every_deriver_cites_it -> any {
    for (path, heading, needle, why) in self.CASES {
        with self.subTest(file=path.name, rule=needle) {
            self.assertIn(needle, section(path, heading), why);
        }
    }
}

impl ArchiveNameIsOnePathComponent.derive(company, role) -> any {
    name: any = f"{company}_{role}".lower().replace(" ", "_");
    name = re.sub("[^\\w]", "", name);
    name = re.sub("_+", "_", name).strip("_");
    return name or None;
}

impl ArchiveNameIsOnePathComponent.test_documented_rule_yields_a_single_path_component -> any {
    for (company, role, expected) in self.DERIVATIONS {
        with self.subTest(company=company, role=role) {
            name: any = self.derive(company, role);
            self.assertEqual(name, expected);
            if name is None {
                continue;
            }
            self.assertNotIn("/", name);
            self.assertNotIn("..", name);
        }
    }
}
