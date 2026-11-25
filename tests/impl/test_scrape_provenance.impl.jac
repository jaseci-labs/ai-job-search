impl _steps(text: builtins.str) -> builtins.dict[builtins.str, builtins.str] {
    result: any = {};
    for part in text.split("\n### ")[1:] {
        heading: any;
        _: any;
        body: any;
        (heading, _, body) = part.partition("\n") as any;
        result[heading.strip()] = body;
    }
    return result;
}

impl ScrapeProvenanceSpec.setUpClass -> any {
    cls.text = SKILL.read_text(encoding="utf-8");
    cls.steps = _steps(cls.text);
}

impl ScrapeProvenanceSpec.test_schema_block_carries_source_field -> any {
    step4: any = self.steps.get("Step 4: Deduplicate & Store", "");
    self.assertIn(
        "\"source\": \"cli/websearch\"",
        step4,
        "the seen_jobs.json schema block lost the source (provenance) field",
    );
}

impl ScrapeProvenanceSpec.test_source_field_is_additive_and_never_backfilled -> any {
    step4: any = self.steps.get("Step 4: Deduplicate & Store", "");
    self.assertIn(
        "`cli` for Step 1b portal-CLI output, `websearch` for the Step 1c fallback",
        step4,
        "Step 4 must define which mechanism each source value names",
    );
    self.assertIn(
        "the mechanism was not recorded",
        step4,
        "Step 4 must forbid back-filling source on entries that predate the field",
    );
}

impl ScrapeProvenanceSpec.test_fallback_results_are_tagged_at_the_source -> any {
    step1: any = self.steps.get("Step 1: Search", "");
    fallback: any = step1.partition("#### 1c. WebSearch fallback")[2];
    self.assertIn(
        "Step 4 persists this as the entry's `source`",
        fallback,
        "Step 1c must tag fallback results so Step 4 has a provenance value to store",
    );
}

impl ScrapeProvenanceSpec.test_step5_summary_names_fallback_portals -> any {
    step5: any = self.steps.get("Step 5: Present Results", "");
    self.assertIn(
        "fallback (websearch):",
        step5,
        "Step 5 must surface which portals ran on the WebSearch fallback this run",
    );
    self.assertIn(
        "omit the line when every portal ran its CLI",
        " ".join(step5.split()),
        "the fallback line must be omitted when every portal ran its CLI, not printed empty",
    );
}

impl TestRecencyFallback.test_step1b_names_a_client_side_fallback_for_flagless_portals -> any {
    text: any = SKILL.read_text(encoding="utf-8");
    self.assertIn(
        "no recency flag",
        text,
        "Step 1b.3 must say what to do when a portal offers no recency flag",
    );
    self.assertIn(
        "filter client-side",
        text,
        "the fallback is filtering results by their `date` field after the call",
    );
    self.assertIn(
        "a sort is not a filter",
        text,
        "the instruction must stop presenting --order (a sort) as interchangeable with a filter",
    );
}
