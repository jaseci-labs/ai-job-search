import json;
import re;
import unittest;

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

def step(title: str) -> str;

class RankCommandSpec(unittest.TestCase) {
    def test_each_section_states_its_rules;
    def test_whole_command_names_the_verdict_field_and_the_defensive_parse;
    def test_step2_dispatches_posting_scorer_and_hands_it_the_key;
    def test_step1_empty_candidates_still_sweeps_and_reports;
    def test_step5_surfaces_a_flagged_posting;
    def test_step3_staleness_is_a_defensively_parsed_flag_never_a_veto_or_a_guess;
    def test_agent_status_contract_matches_the_state_helper;
    def test_step4_preserves_every_field_step2_declares;
    def test_job_scraper_schema_note;
    def test_evaluation_framework_acknowledges_language_gate_tracking;
    def test_settings_and_guards_allow_the_state_tool;
    def test_lint_skills_passes;
}
