import json, re, unittest;

glob STEP_1: str = "Step 1: Load State",
     STEP_2: str = "Step 2: Batch-Fetch and Score",
     STEP_3: str = "Step 3: Aggregate and Rank",
     STEP_4: str = "Step 4: Update State",
     TEMPLATE: str = "Job Ranking - YYYY-MM-DD",
     NOT_PERSISTED_VERBATIM: set[str] = {
         "key",
         "status",
         "language",
         "scores",
         "technical",
         "experience",
         "behavioral",
         "career",
     },
     SECTIONS: dict[str, list[str]] = {
         "Step 0: Parse Input": [
             "`--limit <N>`",
             "default 10",
             "`--top <N>`",
             "They are independent",
         ],
         STEP_1: [
             "-- rank_state candidates --limit 10",
             "deferred",
             "Never read `job_scraper/seen_jobs.json` into the conversation",
         ],
         STEP_2: [
             "posting-scorer",
             "posting_guard",
             "\"guard\"",
             "\"language_gate\"",
             "\"language_note\"",
             "\"PASS\" | \"FAIL\" | \"FLAG\"",
             "distinct from",
         ],
         STEP_3: [
             "Language veto",
             "excludes the job from the shortlist",
             "stored `deadline`",
             "costs no fetch",
             "Expiry sweep",
             "date comparison against values already on disk",
             "never guessed at",
             "revived by a later `--all`",
             "-- rank_state sweep",
             "`posted_date`",
             "`first_seen`",
         ],
         STEP_4: [
             "guard",
             "\"gaps\"",
             "\"strengths\"",
             "verbatim",
             "replaces",
             "untrusted data",
             "\"language_gate\"",
             "\"language_note\"",
             "as important to persist as the score itself",
             "\"deadline\"",
             "from the same Step 2 JSON",
             "absence is not a correction",
             "deliberate exception",
             "immortal to the sweep",
             "retired by Step 3's rule 6 sweep",
             "-- rank_state apply",
             "never re-read to build it",
             "never the bare `location` key",
             "legacy",
             "never applies",
         ],
         TEMPLATE: [
             "Closing soon",
             "Swept",
             "language_gate: FLAG",
             "jobs deferred",
             "re-run `/rank` to continue",
         ],
         "Important Rules": ["persisted with it"],
     };

def step(title: str) -> str {
    return h2(doc(RANK), title);
}

class RankCommandSpec(unittest.TestCase) {
    def test_each_section_states_its_rules {
        for (title, phrases) in SECTIONS.items() {
            with self.subTest(section=title) {
                expect(self, step(title), *phrases);
            }
        }
    }

    def test_whole_command_names_the_verdict_field_and_the_defensive_parse {
        text: str = doc(RANK);
        self.assertTrue(text.startswith("# /rank"), text[:40]);
        expect(
            self,
            text,
            "\"location_verdict\"",
            "\"location_verdict\": \"PASS\"/\"FAIL\"/\"FLAG\"",
            "legacy",
            "Parse stored deadlines defensively",
            "\"fetch_error\"",
        );
        expect_not(self, text, "\"location\":");
        expect_re(self, text, "not a `YYYY-MM-DD` date[^.]*treated exactly like an absent one");
    }

    def test_step2_dispatches_posting_scorer_and_hands_it_the_key {
        step2: str = step(STEP_2);
        expect_not(self, step2, "general-purpose");
        expect(self, step2[:step2.index("Each agent returns a JSON array")], "`key`", "candidates");
        expect_re(self, doc(".claude/agents/posting-scorer.md"), "`key`.*(echo|cop)");
    }

    def test_step1_empty_candidates_still_sweeps_and_reports {
        empty_branch: str = between(step(STEP_1), "If it reports no candidates", "Then read");
        expect(
            self,
            empty_branch,
            "neojac run jobsearch -- rank_state sweep --write",
            "swept",
            "newly_expired",
            "closing_soon",
            "unparseable_deadlines",
            "Skip",
            "Steps 2-4",
        );
        expect_not(self, empty_branch, "--exclude");
    }

    def test_step5_surfaces_a_flagged_posting {
        step5: str = between(doc(RANK), "## Step 5: Present the Shortlist", "\n## Important Rules");
        expect(self, step5, "guard", "⚠");
    }

    def test_step3_staleness_is_a_defensively_parsed_flag_never_a_veto_or_a_guess {
        step3: str = step(STEP_3);
        self.assertIn("⚠", step3.split("`posted_date`", 1)[1][:600]);
        expect_re(
            self,
            " ".join(step3.split()),
            "[Aa]ge is a signal, never a veto",
            "no `posted_date`.*no flag and no guess",
            "defensive-parse rule applies wherever a stored `posted_date` is compared",
        );
    }

    def test_agent_status_contract_matches_the_state_helper {
        union: re.Match | None = re.search(
            "\"status\":\\s*(\"[a-z_]+\"(?:\\s*\\|\\s*\"[a-z_]+\")+)", doc(RANK)
        );
        assert union is not None, "Step 2's JSON contract must spell out the status union";
        self.assertEqual(
            set(re.findall("\"([a-z_]+)\"", union.group(1))), set(rank_state.AGENT_STATUSES)
        );
        self.assertIn("unreachable", rank_state.AGENT_STATUSES);
    }

    def test_step4_preserves_every_field_step2_declares {
        block: str = between(step(STEP_2), "```json", "```");
        fields: list[str] = re.findall("\"([a-z_]+)\":", block);
        self.assertTrue(fields, "could not extract Step 2's JSON field names");
        expect(
            self, step(STEP_4), *[f"\"{f}\"" for f in sorted(set(fields) - NOT_PERSISTED_VERBATIM)]
        );
    }

    def test_job_scraper_schema_note {
        expect(
            self,
            doc(SCRAPER),
            "strengths",
            "gaps",
            "readers tolerate their absence",
            "\"deadline\": \"YYYY-MM-DD\" | null",
            "never infer a deadline",
            "base field rather than a `/rank` extension",
            "location_verdict",
            "language_gate",
            "language_note",
        );
    }

    def test_evaluation_framework_acknowledges_language_gate_tracking {
        gate: str = section(doc(EVALUATION), "## Language Gate", "^## ");
        expect(self, gate, "language_gate", "language_note");
        expect_not(self, gate, "not a field");
    }

    def test_settings_and_guards_allow_the_state_tool {
        rule: str = "Bash(neojac run jobsearch -- rank_state:*)";
        self.assertIn(rule, json.loads(doc(".claude/settings.json"))["permissions"]["allow"]);
        self.assertIn(rule, doc("tools/security_guards.jac"));
    }

    def test_lint_skills_passes {
        lint_skills_passes(self);
    }
}
