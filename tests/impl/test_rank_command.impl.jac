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

impl RankCommandSpec.test_step2_dispatches_posting_scorer_and_returns_guard -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    sections: any = _sections(text);
    step2: any = sections["Step 2: Batch-Fetch and Score"];
    self.assertIn("posting-scorer", step2, "Step 2 must dispatch the posting-scorer agent");
    self.assertNotIn(
        "general-purpose", step2, "Step 2 must no longer dispatch general-purpose agents"
    );
    self.assertIn(
        "posting_guard", step2, "Step 2 must run the integrity gate on each fetched body"
    );
    self.assertIn("\"guard\"", step2, "Step 2's JSON must carry the gate verdict");
    step4: any = sections["Step 4: Update State"];
    self.assertIn("guard", step4, "Step 4 must persist the gate verdict");
    step5: any = re.search(
        "## Step 5: Present the Shortlist(.*?)\\n## Important Rules", text, re.DOTALL
    ).group(1);
    self.assertIn("guard", step5, "Step 5 must surface a flagged posting");
    self.assertIn("⚠", step5);
}

impl RankCommandSpec.test_step2_hands_the_scorer_the_key_it_must_return -> any {
    step2: any = _sections(COMMAND.read_text(encoding="utf-8"))["Step 2: Batch-Fetch and Score"];
    dispatch: any = step2[:step2.index("Each agent returns a JSON array")];
    self.assertIn("`key`", dispatch, "the job list handed to the scorer must carry the key");
    self.assertIn("candidates", dispatch, "the key comes from Step 1's candidates output");
    scorer: any = (REPO / ".claude" / "agents" / "posting-scorer.md").read_text(encoding="utf-8");
    self.assertRegex(
        scorer, "`key`.*(echo|cop)", "the scorer must be told to return the key unchanged"
    );
}

impl RankCommandSpec.test_step1_empty_candidates_still_sweeps_and_reports -> any {
    step1: any = _sections(COMMAND.read_text(encoding="utf-8"))["Step 1: Load State"];
    empty_branch: any = step1.partition("If it reports no candidates")[2].partition("Then read")[0];
    self.assertIn(
        "neojac run jobsearch -- rank_state sweep --write",
        empty_branch,
        "an empty candidate batch must still persist rule 6's expiry sweep",
    );
    self.assertNotIn("--exclude", empty_branch, "no jobs were re-scored on this path");
    for field in ("swept", "newly_expired", "closing_soon", "unparseable_deadlines") {
        self.assertIn(field, empty_branch, f"the empty-run report must consume {field}");
    }
    self.assertIn("Skip", empty_branch);
    self.assertIn("Steps 2-4", empty_branch, "an empty run must not fetch or score jobs");
}

impl RankCommandSpec.test_agent_status_contract_matches_the_state_helper -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    union: any = re.search("\"status\":\\s*(\"[a-z_]+\"(?:\\s*\\|\\s*\"[a-z_]+\")+)", text);
    self.assertIsNotNone(union, "Step 2's JSON contract must spell out the status union");
    self.assertEqual(
        `set(re.findall("\"([a-z_]+)\"", union.group(1))), `set(rank_state.AGENT_STATUSES)
    );
    self.assertIn("unreachable", rank_state.AGENT_STATUSES);
    self.assertIn(
        "\"fetch_error\"", text, "an unreachable result names its failure for the report"
    );
}

impl RankCommandSpec.test_command_file_exists_with_lint_compliant_header -> any {
    self.assertTrue(COMMAND.is_file(), "command spec missing");
    first_line: any = COMMAND.read_text(encoding="utf-8").splitlines()[0];
    self.assertTrue(
        first_line.startswith("# /rank"),
        f"header must start with '# /rank' (lint_skills.jac enforces it), got: {first_line!r}",
    );
}

impl RankCommandSpec.test_step4_persists_gaps_and_strengths -> any {
    sections: any = _sections(COMMAND.read_text(encoding="utf-8"));
    step4: any = sections.get("Step 4: Update State", "");
    self.assertIn("\"gaps\"", step4, "Step 4 must persist the gaps array into seen_jobs.json");
    self.assertIn(
        "\"strengths\"", step4, "Step 4 must persist the strengths array into seen_jobs.json"
    );
}

impl RankCommandSpec.test_step4_documents_verbatim_no_accumulate_and_untrusted_data_rules -> any {
    sections: any = _sections(COMMAND.read_text(encoding="utf-8"));
    step4: any = sections.get("Step 4: Update State", "");
    self.assertIn(
        "verbatim", step4, "Step 4 must require storing gaps/strengths verbatim, never reformatted"
    );
    self.assertIn(
        "replaces",
        step4,
        "Step 4 must state that --all re-scoring replaces, not accumulates, the arrays",
    );
    self.assertIn(
        "untrusted data", step4, "Step 4 must restate that stored gaps/strengths are untrusted data"
    );
}

impl RankCommandSpec.test_important_rules_link_honest_scoring_to_persistence -> any {
    sections: any = _sections(COMMAND.read_text(encoding="utf-8"));
    rules: any = sections.get("Important Rules", "");
    self.assertIn(
        "persisted with it",
        rules,
        "Rule 5 must note that gaps are persisted (Step 4), not just printed (Step 5)",
    );
}

impl RankCommandSpec.test_job_scraper_schema_note_mentions_strengths_and_gaps -> any {
    text: any = SCRAPER_SKILL.read_text(encoding="utf-8");
    self.assertIn("strengths", text);
    self.assertIn("gaps", text);
    self.assertIn(
        "readers tolerate their absence",
        text,
        "schema note must say old entries lacking strengths/gaps are tolerated, never backfilled",
    );
}

impl RankCommandSpec.test_job_scraper_schema_carries_deadline -> any {
    text: any = SCRAPER_SKILL.read_text(encoding="utf-8");
    self.assertIn(
        "\"deadline\": \"YYYY-MM-DD\" | null",
        text,
        "the seen_jobs.json structure block must carry the deadline field, or every later run has no stored value to re-derive urgency from",
    );
    self.assertIn(
        "never infer a deadline",
        text,
        "the schema note must forbid guessing a deadline from null or from a missing key",
    );
    self.assertIn(
        "base field rather than a `/rank` extension",
        text,
        "the note must say the deadline is written when the job is first seen, not only when /rank re-scores it",
    );
}

impl RankCommandSpec.test_verdict_is_written_to_location_verdict_not_bare_location -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    self.assertIn("\"location_verdict\"", text, "Step 2's agent JSON must use location_verdict");
    self.assertIn(
        "\"location_verdict\": \"PASS\"/\"FAIL\"/\"FLAG\"",
        text,
        "Step 4 must persist the verdict under location_verdict",
    );
    self.assertNotIn(
        "\"location\":",
        text,
        "the PASS/FAIL/FLAG verdict must never be written to the bare location key, which the scraper uses for a place",
    );
    self.assertIn(
        "legacy",
        text,
        "Step 4 must carry a migration rule for entries that stored the verdict under the old location key",
    );
}

impl RankCommandSpec.test_job_scraper_schema_note_enumerates_the_veto_fields -> any {
    text: any = SCRAPER_SKILL.read_text(encoding="utf-8");
    for field in ("location_verdict", "language_gate", "language_note") {
        self.assertIn(
            field,
            text,
            f"the seen_jobs schema note must enumerate {field} so the do-not-drop instruction covers it",
        );
    }
}

impl RankCommandSpec.test_evaluation_framework_acknowledges_language_gate_tracking -> any {
    text: any = EVALUATION.read_text(encoding="utf-8");
    gate: any = text.partition("## Language Gate")[2].partition("\n## ")[0];
    self.assertTrue(gate, "04-job-evaluation.md has no Language Gate section");
    self.assertIn(
        "language_gate",
        gate,
        "the Language Gate section must name the language_gate field /rank persists",
    );
    self.assertIn(
        "language_note",
        gate,
        "the Language Gate section must name the language_note field /rank persists",
    );
    self.assertNotIn(
        "not a field", gate, "stale claim: the gate result IS tracked by /scrape and /rank now"
    );
}

impl RankCommandSpec.test_sweep_parses_stored_deadlines_defensively -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    self.assertIn(
        "Parse stored deadlines defensively",
        text,
        "rule 6's sweep must state the defensive-parse rule",
    );
    self.assertRegex(
        text,
        "not a `YYYY-MM-DD` date[^.]*treated exactly like an absent one",
        "a non-ISO stored deadline must be handled as absent, not compared or guessed at",
    );
}

impl RankCommandSpec.test_step2_schema_includes_language_gate_fields -> any {
    sections: any = _sections(COMMAND.read_text(encoding="utf-8"));
    step2: any = sections.get("Step 2: Batch-Fetch and Score", "");
    self.assertIn(
        "\"language_gate\"", step2, "Step 2's scoring-agent JSON must include language_gate"
    );
    self.assertIn(
        "\"language_note\"", step2, "Step 2's scoring-agent JSON must include language_note"
    );
    self.assertIn(
        "\"PASS\" | \"FAIL\" | \"FLAG\"",
        step2,
        "language_gate must use the same PASS/FAIL/FLAG verdict set as the location veto",
    );
    self.assertIn(
        "distinct from",
        step2,
        "spec must distinguish language_gate/language_note from the pre-existing 'language' field (which records the posting's own language, not a veto verdict) - the two are easy to conflate",
    );
}

impl RankCommandSpec.test_step3_documents_language_veto -> any {
    sections: any = _sections(COMMAND.read_text(encoding="utf-8"));
    step3: any = sections.get("Step 3: Aggregate and Rank", "");
    self.assertIn(
        "Language veto",
        step3,
        "Step 3 must document a Language veto rule, mirroring the existing Location veto",
    );
    self.assertIn(
        "excludes the job from the shortlist",
        step3,
        "a language_gate FAIL must be documented as excluding the job, same as a location FAIL",
    );
}

impl RankCommandSpec.test_step4_persists_language_gate_and_language_note -> any {
    sections: any = _sections(COMMAND.read_text(encoding="utf-8"));
    step4: any = sections.get("Step 4: Update State", "");
    self.assertIn(
        "\"language_gate\"", step4, "Step 4 must persist language_gate into seen_jobs.json"
    );
    self.assertIn(
        "\"language_note\"", step4, "Step 4 must persist language_note into seen_jobs.json"
    );
    self.assertIn(
        "as important to persist as the score itself",
        step4,
        "Step 4 must call out that the veto fields (location/language_gate/language_note) are not optional extras",
    );
}

impl RankCommandSpec.test_step4_persists_deadline -> any {
    sections: any = _sections(COMMAND.read_text(encoding="utf-8"));
    step4: any = sections.get("Step 4: Update State", "");
    self.assertIn("\"deadline\"", step4, "Step 4 must persist the deadline into seen_jobs.json");
    self.assertIn(
        "from the same Step 2 JSON",
        step4,
        "Step 4 must source the persisted deadline from the scoring agent's JSON, not from a guess",
    );
    self.assertIn(
        "absence is not a correction",
        step4,
        "Step 4 must keep an existing stored deadline when the agent returned null, so a fresh run never blanks a date the scraper already recorded",
    );
}

impl RankCommandSpec.test_step3_reads_stored_deadline_without_fetch -> any {
    sections: any = _sections(COMMAND.read_text(encoding="utf-8"));
    step3: any = sections.get("Step 3: Aggregate and Rank", "");
    self.assertIn(
        "stored `deadline`",
        step3,
        "Step 3 must take the deadline from seen_jobs.json for a job that already carries one",
    );
    self.assertIn(
        "costs no fetch",
        step3,
        "Step 3 must state that the stored value costs no fetch - that is the entire point of persisting it",
    );
}

impl RankCommandSpec.test_step3_documents_expiry_sweep_over_ranked_entries -> any {
    sections: any = _sections(COMMAND.read_text(encoding="utf-8"));
    step3: any = sections.get("Step 3: Aggregate and Rank", "");
    self.assertIn(
        "Expiry sweep",
        step3,
        "Step 3 must document a sweep over already-ranked entries this run did not re-score",
    );
    self.assertIn(
        "date comparison against values already on disk",
        step3,
        "the sweep must be a pure on-disk comparison - no fetch, no agent",
    );
    step5: any = sections.get("Job Ranking - YYYY-MM-DD", "");
    self.assertIn(
        "Closing soon",
        step5,
        "Step 5's template must name the Closing soon heading rule 6 lists under",
    );
}

impl RankCommandSpec.test_step3_sweep_states_its_two_boundary_rules -> any {
    step3: any = _sections(COMMAND.read_text(encoding="utf-8")).get(
        "Step 3: Aggregate and Rank", ""
    );
    self.assertIn(
        "never guessed at",
        step3,
        "rule 6 must say an entry with no stored deadline is left alone - it is the majority case, and inferring one would retire jobs on a date nobody set",
    );
    self.assertIn(
        "revived by a later `--all`",
        step3,
        "rule 6 must state that --all re-scores expired entries, or the sweep is an irreversible automated status change",
    );
}

impl RankCommandSpec.test_step4_sweep_is_named_as_the_exception_to_idempotency -> any {
    step4: any = _sections(COMMAND.read_text(encoding="utf-8")).get("Step 4: Update State", "");
    self.assertIn(
        "deliberate exception",
        step4,
        "Step 4's idempotency line must name rule 6's sweep as its exception, or the spec tells the reader both that already-ranked entries are skipped and that they are swept",
    );
}

impl RankCommandSpec.test_step4_null_deadline_rule_states_its_interlock_with_the_sweep -> any {
    step4: any = _sections(COMMAND.read_text(encoding="utf-8")).get("Step 4: Update State", "");
    self.assertIn(
        "immortal to the sweep",
        step4,
        "the null-overwrite rule must state why it matters here: erasing a stored deadline also removes the entry from rule 6's reach forever",
    );
}

impl RankCommandSpec.test_step5_reports_the_sweep_counts -> any {
    step5: any = _sections(COMMAND.read_text(encoding="utf-8")).get("Job Ranking - YYYY-MM-DD", "");
    self.assertIn(
        "Swept",
        step5,
        "Step 5's template must report how many already-ranked entries the sweep checked and how many it retired - it rewrites seen_jobs.json silently otherwise",
    );
}

impl RankCommandSpec.test_step4_persists_the_sweeps_expiry -> any {
    sections: any = _sections(COMMAND.read_text(encoding="utf-8"));
    step4: any = sections.get("Step 4: Update State", "");
    self.assertIn(
        "retired by Step 3's rule 6 sweep",
        step4,
        "Step 4 must persist the Step 3 rule 6 sweep's expiries, not just the ones the scoring agents reported",
    );
}

impl RankCommandSpec.test_step5_documents_language_flag_marker -> any {
    sections: any = _sections(COMMAND.read_text(encoding="utf-8"));
    step5_rules: any = sections.get("Job Ranking - YYYY-MM-DD", "");
    self.assertIn(
        "language_gate: FLAG",
        step5_rules,
        "Step 5's presentation rules must document the ⚠ marker + language_note callout for a shortlisted FLAG job, mirroring the existing location FLAG treatment",
    );
}

impl RankCommandSpec.test_lint_skills_passes -> any {
    result: any = subprocess.run([*tool("lint_skills")], cwd=REPO, capture_output=True, text=True);
    self.assertEqual(
        result.returncode, 0, f"lint_skills.jac failed:\n{result.stdout}{result.stderr}"
    );
}

impl PostedDateStalenessSpec.setUp -> any {
    self.step3 = _sections(COMMAND.read_text(encoding="utf-8")).get(
        "Step 3: Aggregate and Rank", ""
    );
    self.assertTrue(self.step3, "Step 3 section missing from rank.md");
    self.flat = " ".join(self.step3.split());
}

impl PostedDateStalenessSpec.test_step3_consumes_posted_date -> any {
    self.assertIn(
        "`posted_date`",
        self.step3,
        "Step 3 never reads the posted_date /scrape persists, so a posting's age is stored but still invisible at rank time - the exact #390 gap",
    );
    self.assertIn(
        "⚠",
        self.step3.split("`posted_date`", 1)[1][:600],
        "the staleness rule must surface age as a visible ⚠ marker, like the location and language FLAG treatments",
    );
}

impl PostedDateStalenessSpec.test_staleness_is_a_flag_never_a_veto -> any {
    self.assertRegex(
        self.flat,
        "[Aa]ge is a signal, never a veto",
        "staleness must keep FLAG semantics - the #390 posting was 27 months old AND still live, so excluding on age would bury real openings",
    );
}

impl PostedDateStalenessSpec.test_staleness_never_inferred_for_absent_values -> any {
    self.assertRegex(
        self.flat,
        "no `posted_date`.*no flag and no guess",
        "entries predating the field must get no staleness signal - inferring age from first_seen would flag jobs on a date nobody posted",
    );
    self.assertIn(
        "`first_seen`",
        self.step3,
        "the rule must name first_seen as the forbidden inference source",
    );
}

impl PostedDateStalenessSpec.test_staleness_parses_posted_date_defensively -> any {
    self.assertRegex(
        self.flat,
        "defensive-parse rule applies wherever a stored `posted_date` is compared",
        "posted_date comparisons must carry rule 6's defensive-parse rule - the contract test pins the field's presence, not its format, and portals have shipped free-text shapes into stored date fields before",
    );
}

impl RankBatchLimitSpec.setUp -> any {
    self.sections = _sections(COMMAND.read_text(encoding="utf-8"));
}

impl RankBatchLimitSpec.test_step0_documents_default_limit_distinct_from_top -> any {
    step0: any = self.sections.get("Step 0: Parse Input", "");
    self.assertIn("`--limit <N>`", step0);
    self.assertIn("default 10", step0);
    self.assertIn("`--top <N>`", step0);
    self.assertIn(
        "They are independent",
        step0,
        "--limit must bound scoring without being confused with shortlist size",
    );
}

impl RankBatchLimitSpec.test_step1_applies_limit_via_the_state_tool -> any {
    step1: any = self.sections.get("Step 1: Load State", "");
    self.assertIn(
        "-- rank_state candidates --limit 10",
        step1,
        "Step 1 must select candidates with the CLI, passing --limit through to it",
    );
    self.assertIn(
        "deferred",
        step1,
        "deferred jobs must remain eligible for a later run - the tool's own output must document that they keep their current status",
    );
}

impl RankBatchLimitSpec.test_step5_reports_deferral_and_how_to_continue -> any {
    `report: any = self.sections.get("Job Ranking - YYYY-MM-DD", "");
    self.assertIn("jobs deferred", `report);
    self.assertIn("re-run `/rank` to continue", `report);
}

impl RankStateToolSpec.setUp -> any {
    self.text = COMMAND.read_text(encoding="utf-8");
    self.sections = _sections(self.text);
}

impl RankStateToolSpec._step2_result_fields -> builtins.list[builtins.str] {
    step2: any = self.sections.get("Step 2: Batch-Fetch and Score", "");
    block: any = step2.split("```json", 1)[1].split("```", 1)[0];
    fields: any = re.findall("\"([a-z_]+)\":", block);
    self.assertTrue(fields, "could not extract Step 2's JSON field names - block shape changed");
    return fields;
}

impl RankStateToolSpec.test_step1_never_reads_the_state_file_manually -> any {
    step1: any = self.sections.get("Step 1: Load State", "");
    self.assertIn(
        "Never read `job_scraper/seen_jobs.json` into the conversation",
        step1,
        "Step 1 must forbid the manual read this fix removes",
    );
    self.assertIn("-- rank_state candidates", step1);
}

impl RankStateToolSpec.test_step4_writes_back_through_apply_not_by_hand -> any {
    step4: any = self.sections.get("Step 4: Update State", "");
    self.assertIn(
        "-- rank_state apply",
        step4,
        "Step 4 must write results with the CLI; re-emitting seen_jobs.json by hand reproduces the exact cost this fix removes",
    );
    self.assertIn(
        "never re-read to build it",
        step4,
        "apply's own printed output, not a fresh read of the state file, must be what Step 5's report is built from",
    );
}

impl RankStateToolSpec.test_step4_preserves_every_field_step2_declares -> any {
    step4: any = self.sections.get("Step 4: Update State", "");
    not_persisted_verbatim: any = {
        "key",
        "status",
        "language",
        "scores",
        "technical",
        "experience",
        "behavioral",
        "career",
    };
    must_persist: any = `set(self._step2_result_fields()) - not_persisted_verbatim;
    missing: any = [f for f in must_persist if f"\"{f}\"" not in step4];
    self.assertFalse(missing, f"Step 4 does not mention persisting: {missing}");
}

impl RankStateToolSpec.test_step4_documents_the_location_verdict_legacy_migration -> any {
    step4: any = self.sections.get("Step 4: Update State", "");
    self.assertIn(
        "never the bare `location` key",
        step4,
        "Step 4 must forbid writing the verdict to the scraper's place field",
    );
    self.assertIn(
        "legacy",
        step4,
        "Step 4 must document the location_verdict-absent migration from the old location key",
    );
}

impl RankStateToolSpec.test_step4_documents_deadline_null_is_not_a_correction -> any {
    step4: any = self.sections.get("Step 4: Update State", "");
    self.assertIn(
        "absence is not a correction",
        step4,
        "a null deadline from the agent must never erase a stored one",
    );
}

impl RankStateToolSpec.test_step3_sweep_runs_through_the_tool -> any {
    step3: any = self.sections.get("Step 3: Aggregate and Rank", "");
    self.assertIn(
        "-- rank_state sweep",
        step3,
        "rule 6's expiry sweep must run through the CLI, not a manual re-read",
    );
}

impl RankStateToolSpec.test_tracker_stays_read_only -> any {
    step4: any = self.sections.get("Step 4: Update State", "");
    self.assertIn(
        "never applies",
        step4,
        "Step 4 must still state that job_search_tracker.csv is read-only for /rank",
    );
}

impl RankStateToolSpec.test_settings_and_guards_allow_the_new_tool -> any {
    settings: any = json.loads((REPO / ".claude" / "settings.json").read_text(encoding="utf-8"));
    allow: any = settings["permissions"]["allow"];
    guards: any = (REPO / "tools" / "security_guards.jac").read_text(encoding="utf-8");
    for `entry in ("Bash(neojac run jobsearch -- rank_state:*)",) {
        self.assertIn(`entry, allow, f"{`entry} missing from .claude/settings.json");
        self.assertIn(
            `entry, guards, f"{`entry} missing from security_guards.jac's reviewed allowlist"
        );
    }
}
