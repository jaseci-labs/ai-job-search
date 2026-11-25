impl ScrapeProvenanceSpec.test_source_field_is_stored_defined_tagged_and_reported {
    step4: str = STEPS.get("Step 4: Deduplicate & Store", "");
    step5: str = STEPS.get("Step 5: Present Results", "");
    cases: list[tuple[str, str]] = [
        (step4, "\"source\": \"cli/websearch\""),
        (step4, "`cli` for Step 1b portal-CLI output, `websearch` for the Step 1c fallback"),
        (step4, "the mechanism was not recorded"),
        (
            STEPS.get("Step 1: Search", "").partition("#### 1c. WebSearch fallback")[2],
            "Step 4 persists this as the entry's `source`",
        ),
        (step5, "fallback (websearch):"),
        (" ".join(step5.split()), "omit the line when every portal ran its CLI"),
    ];
    for (section, phrase) in cases {
        with self.subTest(phrase=phrase) {
            self.assertIn(phrase, section);
        }
    }
}

impl TestRecencyFallback.test_step1b_names_a_client_side_fallback_for_flagless_portals {
    for phrase in ("no recency flag", "filter client-side", "a sort is not a filter") {
        self.assertIn(phrase, SKILL);
    }
}
