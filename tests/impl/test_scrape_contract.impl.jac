impl derive_contract_fields -> builtins.frozenset[builtins.str] {
    text: any = SCRAPER_SKILL.read_text(encoding="utf-8");
    `match: any = _CONTRACT_SENTENCE.search(text);
    if `match is None {
        raise AssertionError("Step 2 contract sentence not found in job-scraper/SKILL.md");
    }
    fields_text: any = re.sub("\\s+and\\s+", ",", `match.group(1));
    fields: any = {f.strip().lower() for f in fields_text.split(",") if f.strip()};
    return frozenset(fields);
}

impl search_output_source(search_ts: Path) -> builtins.str {
    helpers_ts: any = search_ts.parent.parent / "helpers.ts";
    files: any = [search_ts, helpers_ts] if helpers_ts.exists() else [search_ts];
    return "\n".join(f.read_text(encoding="utf-8") for f in files);
}

impl ScrapeSearchOutputContractTests.test_step2_contract_sentence_is_found_in_the_scraper_skill -> any {
    fields: any = derive_contract_fields();
    self.assertGreaterEqual(fields, {"title", "company", "location", "date", "url"});
}

impl ScrapeSearchOutputContractTests.test_every_portal_cli_emits_the_step2_contract_fields -> any {
    contract: any = derive_contract_fields();
    failures: builtins.list[builtins.str] = [];
    for portal in PORTAL_CLIS {
        search_ts: any = portal / "cli" / "src" / "commands" / "search.ts";
        if not search_ts.exists() {
            failures.append(f"{portal.name}: no cli/src/commands/search.ts");
            continue;
        }
        source: any = search_output_source(search_ts);
        emitted: any = `set(re.findall("^\\s*([a-zA-Z_][a-zA-Z0-9_]*):", source, re.MULTILINE));
        missing: any = sorted(contract - emitted);
        if missing {
            failures.append(f"{portal.name}: missing {missing} in search output");
        }
    }
    self.assertEqual([], failures, "; ".join(failures));
}

impl derive_stored_fields -> builtins.frozenset[builtins.str] {
    text: any = SCRAPER_SKILL.read_text(encoding="utf-8");
    `match: any = _STEP4_SCHEMA_BLOCK.search(text);
    if `match is None {
        raise AssertionError(
            "Step 4 seen_jobs.json schema block not found in job-scraper/SKILL.md"
        );
    }
    return frozenset(re.findall("\"([a-z_]+)\":", `match.group(1)));
}

impl SeenJobsPostingDateTests.test_step4_schema_persists_a_posting_date -> any {
    stored: any = derive_stored_fields();
    self.assertIn(
        "posted_date",
        stored,
        "Step 4's seen_jobs.json schema stores no posting-date field, so a posting's age is unrecoverable after the run that scraped it",
    );
}

impl SeenJobsPostingDateTests.test_the_step2_date_field_survives_into_storage -> any {
    contract: any = derive_contract_fields();
    self.assertIn("date", contract, "Step 2 no longer guarantees a posting date");
    stored: any = derive_stored_fields();
    self.assertIn(
        "posted_date",
        stored,
        "Step 2 guarantees a posting `date` and CI enforces every CLI emits it, but Step 4 discards it at write time",
    );
}

impl SeenJobsPostingDateTests.test_posted_date_semantics_are_documented -> any {
    text: any = SCRAPER_SKILL.read_text(encoding="utf-8");
    self.assertIn("`posted_date`", text, "posted_date is in the schema but never documented");
    self.assertRegex(
        text,
        "never infer a posting date",
        "posted_date must carry the same never-backfill rule as `deadline`",
    );
}

impl SeenJobsEmploymentTypeTests.test_step4_schema_persists_employment_type -> any {
    self.assertIn(
        "employment_type",
        derive_stored_fields(),
        "Step 4's seen_jobs.json schema stores no employment type",
    );
}

impl SeenJobsEmploymentTypeTests.test_schema_lists_every_allowed_value_and_null -> any {
    text: any = SCRAPER_SKILL.read_text(encoding="utf-8");
    line: any = next(l for l in text.splitlines() if l.strip().startswith("\"employment_type\""));
    for value in EMPLOYMENT_TYPES {
        self.assertIn(f"\"{value}\"", line);
    }
    self.assertIn("null", line);
}

impl SeenJobsEmploymentTypeTests.test_employment_type_semantics_are_documented -> any {
    text: any = SCRAPER_SKILL.read_text(encoding="utf-8");
    self.assertRegex(
        text,
        "never infer an employment type",
        "employment_type must carry the same never-backfill rule as `posted_date`",
    );
}

impl SeenJobsEmploymentTypeTests._rank_employment_paragraph -> builtins.str {
    text: any = RANK_COMMAND.read_text(encoding="utf-8");
    start: any = text.find("**Employment type:**");
    if start == -1 {
        return "";
    }
    end: any = text.find("\n\n", start);
    return text[start:] if end == -1 else text[start:end];
}

impl SeenJobsEmploymentTypeTests.test_rank_shows_it_as_a_flag_never_a_veto -> any {
    paragraph: any = self._rank_employment_paragraph();
    self.assertIn("employment_type", paragraph, "/rank never reads the stored employment type");
    self.assertRegex(paragraph, "never a veto", "the mismatch flag must not veto");
}

impl SeenJobsEmploymentTypeTests.test_rank_marks_the_type_and_its_separator_as_optional -> any {
    text: any = RANK_COMMAND.read_text(encoding="utf-8");
    self.assertIn("(78)**[ · <employment type>]", text);
    self.assertRegex(self._rank_employment_paragraph(), "separator included");
}

impl SeenJobsEmploymentTypeTests.test_portal_detail_output_counts_as_a_source -> any {
    text: any = SCRAPER_SKILL.read_text(encoding="utf-8");
    start: any = text.index("**Employment type:**");
    self.assertIn("`detail` output", text[start:text.index("\n\n", start)]);
}

impl SeenJobsDedupContinuityTests.test_existing_urls_are_seen_regardless_of_key -> any {
    text: any = SCRAPER_SKILL.read_text(encoding="utf-8");
    self.assertRegex(
        text,
        "URL matches any existing `(?:job_scraper/)?seen_jobs\\.json` entry, regardless of\\s+that entry's key",
        "legacy seen_jobs entries must be matched by URL during the key-rule transition",
    );
}

impl SeenJobsDedupContinuityTests.test_step4_presentation_mentions_url_deduplication -> any {
    text: any = SCRAPER_SKILL.read_text(encoding="utf-8");
    self.assertRegex(text, "matched by URL or\\s+company\\+title");
}

impl PortalQuerySyntaxTests.test_step1b_points_at_the_query_syntax_line -> any {
    text: any = SCRAPER_SKILL.read_text(encoding="utf-8");
    step1b: any = re.search("#### 1b\\..*?(?=#### 1c\\.)", text, re.DOTALL);
    self.assertIsNotNone(step1b, "Step 1b section not found");
    self.assertIn(
        "`Query syntax:`",
        step1b.group(0),
        "Step 1b no longer defers quoting to the portal's Query syntax line",
    );
    self.assertIn("inside the argument the CLI receives", step1b.group(0));
    self.assertIn("deduplicate the pool by URL before Step 2", step1b.group(0));
}

impl PortalQuerySyntaxTests.test_every_installed_portal_skill_has_a_query_syntax_line -> any {
    missing: any = [
        portal.name
        for portal in PORTAL_CLIS
        if not _QUERY_SYNTAX_LINE.search((portal / "SKILL.md").read_text(encoding="utf-8"))
    ];
    self.assertEqual(
        [], missing, "portal SKILL.md files without a `Query syntax:` line: " + ", ".join(missing)
    );
}
