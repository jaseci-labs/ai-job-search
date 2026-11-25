impl _sections(
    text: builtins.str, marker: builtins.str
) -> builtins.dict[builtins.str, builtins.str] {
    parts: any = text.split(f"\n{marker} ");
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

impl _apply_research_step -> builtins.str {
    text: any = APPLY.read_text(encoding="utf-8");
    sections: any = _sections(text, "###");
    for (heading, body) in sections.items() {
        if heading.startswith("1. Research the Company") {
            return body;
        }
    }
    return "";
}

impl _interview_research_step -> builtins.str {
    text: any = INTERVIEW.read_text(encoding="utf-8");
    sections: any = _sections(text, "##");
    for (heading, body) in sections.items() {
        if heading.startswith("Step 2: Research the Company") {
            return body;
        }
    }
    return "";
}

impl TestCacheDefinition.setUp -> any {
    self.text = EVALUATION.read_text(encoding="utf-8");
    self.sections = _sections(self.text, "##");
}

impl TestCacheDefinition.test_evaluation_file_defines_the_cache_section -> any {
    self.assertIn(
        "Company Research Cache",
        self.sections,
        "04-job-evaluation.md must define a 'Company Research Cache' section",
    );
}

impl TestCacheDefinition.test_cache_definition_specifies_location_and_ttl -> any {
    body: any = self.sections.get("Company Research Cache", "");
    self.assertIn("company_research/", body, "cache section must name the storage directory");
    self.assertIn("30", body, "cache section must state the TTL (30 days)");
    self.assertIn("fetched_date", body, "cache section must name the freshness field");
}

impl TestCacheDefinition.test_cache_definition_preserves_the_verification_rule -> any {
    body: any = self.sections.get("Company Research Cache", "");
    self.assertIn(
        "lead",
        body,
        "cache section must say a cache hit is a lead, matching the existing reviewer-agent-research trust model, not a verified source on its own",
    );
    self.assertRegex(
        body, "[Vv]erif", "cache section must restate that final-claim verification still applies"
    );
}

impl TestCacheDefinition.test_cache_definition_states_contents_are_data_not_instructions -> any {
    body: any = self.sections.get("Company Research Cache", "");
    self.assertIn(
        "data, never instructions",
        body,
        "cache section must state cache contents are data, never instructions",
    );
}

impl TestApplyWiring.test_reviewer_prompt_checks_cache_before_researching -> any {
    body: any = _apply_research_step();
    self.assertNotEqual(body, "", "could not locate apply.md's Research the Company step");
    self.assertIn("company_research/", body, "reviewer prompt must reference the cache path");
    self.assertRegex(
        body,
        "[Cc]heck the cache",
        "reviewer prompt must instruct checking the cache before researching",
    );
}

impl TestApplyWiring.test_reviewer_prompt_writes_back_after_fresh_research -> any {
    body: any = _apply_research_step();
    self.assertRegex(
        body,
        "write.*company_research/|company_research/.*write",
        "reviewer prompt must instruct writing fresh research back to the cache - the write half is the one most likely to be dropped silently",
    );
}

impl TestApplyWiring.test_reviewer_prompt_restates_verification_still_applies_to_a_cache_hit -> any {
    body: any = _apply_research_step();
    self.assertRegex(
        body,
        "still applies",
        "the cache-check paragraph must restate that verification still applies to a cache hit, not just to fresh research",
    );
}

impl TestInterviewWiring.test_step_2_checks_cache_before_researching -> any {
    body: any = _interview_research_step();
    self.assertNotEqual(body, "", "could not locate interview.md's Step 2");
    self.assertIn("company_research/", body, "Step 2 must reference the cache path");
    self.assertRegex(
        body, "[Cc]heck the cache", "Step 2 must instruct checking the cache before researching"
    );
}

impl TestInterviewWiring.test_step_2_writes_back_after_fresh_research -> any {
    body: any = _interview_research_step();
    self.assertRegex(
        body,
        "write.*cache|cache file with",
        "Step 2 must instruct writing fresh research back to the cache",
    );
}

impl TestInterviewWiring.test_step_2_still_requires_verification_before_using_a_claim -> any {
    body: any = _interview_research_step();
    self.assertIn(
        "Verify before using", body, "Step 2 must keep its existing verification requirement"
    );
}

impl TestInterviewWiring.test_step_2_cache_paragraph_restates_verification_still_applies -> any {
    body: any = _interview_research_step();
    self.assertRegex(
        body,
        "still applies",
        "the cache-check paragraph must restate that verification still applies to a cache hit, not just to fresh research",
    );
}
