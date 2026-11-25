impl section(path: Path, heading: builtins.str) -> builtins.str {
    text: any = path.read_text(encoding="utf-8");
    start: any = text.index(heading) + len(heading);
    rest: any = text[start:];
    end: any = re.search("^#{1,4} ", rest, re.MULTILINE);
    return rest[:end.start()] if end else rest;
}

impl VocabularyBlockExists.test_outcome_has_vocabulary_block -> any {
    self.assertIn(
        VOCAB_ANCHOR,
        OUTCOME.read_text(encoding="utf-8"),
        "/outcome must contain the ## Tracker status vocabulary block — that block is the single source of truth for tracker CSV spellings",
    );
}

impl VocabularyBlockExists.test_vocabulary_block_lists_underscore_canonical_spellings -> any {
    vocab: any = section(OUTCOME, VOCAB_ANCHOR);
    for canonical in ("no_response", "offer_declined") {
        self.assertIn(
            f"`{canonical}`",
            vocab,
            f"The vocabulary block must list `{canonical}` as a canonical spelling",
        );
    }
}

impl VocabularyBlockExists.test_vocabulary_block_has_read_tolerance_line -> any {
    vocab: any = section(OUTCOME, VOCAB_ANCHOR);
    self.assertIn(
        "no response",
        vocab,
        "The vocabulary block must mention the legacy space spelling 'no response' so readers know to accept it on read",
    );
    self.assertIn(
        "offer declined",
        vocab,
        "The vocabulary block must mention the legacy space spelling 'offer declined' so readers know to accept it on read",
    );
}

impl VocabularyBlockExists.test_vocabulary_block_states_equivalence_of_space_forms -> any {
    vocab: any = section(OUTCOME, VOCAB_ANCHOR);
    self.assertIn(
        "same values",
        vocab,
        "The vocabulary block must state that the space spellings are the same values as the canonical underscore forms",
    );
    self.assertIn(
        "not separate statuses",
        vocab,
        "The vocabulary block must state that the space spellings are not separate statuses",
    );
    self.assertIn(
        "equally",
        vocab,
        "The vocabulary block must state that the space spellings are equally Final, so finality decisions cover them",
    );
}

impl VocabularyBlockExists.test_vocabulary_block_defines_open_by_exclusion -> any {
    vocab: any = section(OUTCOME, VOCAB_ANCHOR);
    self.assertIn(
        "everything else",
        vocab,
        "The vocabulary block must define Open as everything not in the Final list, not as a second explicit list that can drift",
    );
}

impl VocabularyBlockExists.test_step1_section_contains_all_items -> any {
    step1: any = section(OUTCOME, "## Step 1: Load State and Identify the Application");
    for needle in ("With an argument", "Without an argument", "Derive the archive") {
        self.assertIn(
            needle,
            step1,
            f"Step 1's numbered list must be intact - '{needle}' must sit inside Step 1, not under the vocabulary heading",
        );
    }
}

impl VocabularyBlockExists.test_outcome_step4_writes_underscore_forms -> any {
    step4: any = section(OUTCOME, "## Step 4: Update the Tracker");
    self.assertIn(
        "no_response",
        step4,
        "Step 4 must write `no_response` (underscore), not `no response` (space)",
    );
    self.assertIn(
        "offer_declined",
        step4,
        "Step 4 must write `offer_declined` (underscore), not `offer declined` (space)",
    );
}

impl ReadersBucketMap.test_html_report_bucket_includes_space_and_underscore_forms -> any {
    step1: any = section(HTML_REPORT, "## Step 1: Collect Data");
    self.assertIn(
        "no response",
        step1,
        "/html-report must accept the legacy 'no response' (space) form so that existing trackers are not silently excluded from stats",
    );
    self.assertIn(
        "no_response",
        step1,
        "/html-report must accept the canonical 'no_response' (underscore) form",
    );
    self.assertIn(
        "offer declined", step1, "/html-report must accept the legacy 'offer declined' (space) form"
    );
    self.assertIn(
        "offer_declined",
        step1,
        "/html-report must accept the canonical 'offer_declined' (underscore) form",
    );
}

impl ReadersBucketMap.test_html_report_bucket_map_has_catch_all -> any {
    step1: any = section(HTML_REPORT, "## Step 1: Collect Data");
    self.assertIn(
        "anything else",
        step1,
        "The bucket map must have a catch-all line for unrecognised tracker values",
    );
    self.assertIn(
        "unrecognised",
        step1,
        "The catch-all must name the unrecognised value once so the drop is visible instead of silent",
    );
}

impl ReadersBucketMap.test_html_report_bucket_does_not_contain_interview_only -> any {
    step1: any = section(HTML_REPORT, "## Step 1: Collect Data");
    self.assertNotIn(
        "interview_only",
        step1,
        "`interview_only` must not appear in /html-report's tracker bucket map — it is part of the archive `outcome.md` Status: enum, not a tracker CSV value",
    );
}

impl ReadersBucketMap.test_gmail_sync_references_vocabulary_block -> any {
    step2_text: any = section(GMAIL_SYNC, "## Step 2: Load State");
    self.assertIn(
        "Tracker status vocabulary",
        step2_text,
        "/gmail-sync Step 2 must reference the /outcome vocabulary block instead of restating the final-status set with its own spellings",
    );
    self.assertNotIn(
        "no response",
        step2_text,
        "/gmail-sync Step 2 must not restate the space spellings locally - the vocabulary block is the single source for what counts as final, and a second local list is what drifted in #298",
    );
}

impl ReadersBucketMap.test_notion_sync_normalises_status_before_write -> any {
    step4_text: any = section(NOTION_SYNC, "## Step 4: Upsert Database Rows");
    self.assertIn(
        "never push a space form",
        step4_text,
        "/notion-sync Step 4 must never write a space-form status to Notion",
    );
    self.assertIn(
        "Tracker status vocabulary",
        step4_text,
        "/notion-sync Step 4 must map space forms per the /outcome vocabulary block",
    );
}

impl ReadersBucketMap.test_notion_sync_uses_underscore_status_spellings -> any {
    step3_text: any = section(NOTION_SYNC, "## Step 3: Load Sync State and Locate the Database");
    self.assertIn(
        "no_response",
        step3_text,
        "/notion-sync Step 3 must list `no_response` (underscore) as a Status option so it matches what /outcome writes to the tracker",
    );
    self.assertIn(
        "offer_declined",
        step3_text,
        "/notion-sync Step 3 must list `offer_declined` (underscore) as a Status option so it matches what /outcome writes to the tracker",
    );
    self.assertNotIn(
        "no response",
        step3_text,
        "/notion-sync Step 3 must not list 'no response' (space) as the primary option — Notion creates a distinct select value for each unique string, so mixing spellings creates duplicate options in the database",
    );
}

impl ReaderCases.test_all_reader_cases -> any {
    for (path, heading, needle, why) in self.CASES {
        with self.subTest(file=path.name, rule=needle) {
            haystack: any = section(path, heading) if heading else path.read_text(encoding="utf-8");
            self.assertIn(needle, haystack, why);
        }
    }
}
