import builtins;

import json;

import re;

import subprocess;

import sys;

import unittest;

import from pathlib { Path }

glob _HAVE_YAML: any;

glob yaml: any;

glob REPO: any;

glob COMMAND: any;

glob SCRAPER_SKILL: any;

glob EVALUATION: any;

with entry {
    try {
        import yaml;
        _HAVE_YAML = True;
    } except ImportError {
        _HAVE_YAML = False;
    }

    REPO = Path(__file__).resolve().parent.parent;
    COMMAND = REPO / ".claude" / "commands" / "rank.md";
    SCRAPER_SKILL = REPO / ".claude" / "skills" / "job-scraper" / "SKILL.md";
    EVALUATION = REPO / ".claude" / "skills" / "job-application-assistant" / "04-job-evaluation.md";
}

def _sections(text: builtins.str) -> builtins.dict[builtins.str, builtins.str];

class RankCommandSpec(unittest.TestCase) {
    def test_step2_dispatches_posting_scorer_and_returns_guard -> any;

    def test_step2_hands_the_scorer_the_key_it_must_return -> any;

    def test_step1_empty_candidates_still_sweeps_and_reports -> any;

    def test_agent_status_contract_matches_the_state_helper -> any;

    def test_command_file_exists_with_lint_compliant_header -> any;

    def test_step4_persists_gaps_and_strengths -> any;

    def test_step4_documents_verbatim_no_accumulate_and_untrusted_data_rules -> any;

    def test_important_rules_link_honest_scoring_to_persistence -> any;

    def test_job_scraper_schema_note_mentions_strengths_and_gaps -> any;

    def test_job_scraper_schema_carries_deadline -> any;

    def test_verdict_is_written_to_location_verdict_not_bare_location -> any;

    def test_job_scraper_schema_note_enumerates_the_veto_fields -> any;

    def test_evaluation_framework_acknowledges_language_gate_tracking -> any;

    def test_sweep_parses_stored_deadlines_defensively -> any;

    def test_step2_schema_includes_language_gate_fields -> any;

    def test_step3_documents_language_veto -> any;

    def test_step4_persists_language_gate_and_language_note -> any;

    def test_step4_persists_deadline -> any;

    def test_step3_reads_stored_deadline_without_fetch -> any;

    def test_step3_documents_expiry_sweep_over_ranked_entries -> any;

    def test_step3_sweep_states_its_two_boundary_rules -> any;

    def test_step4_sweep_is_named_as_the_exception_to_idempotency -> any;

    def test_step4_null_deadline_rule_states_its_interlock_with_the_sweep -> any;

    def test_step5_reports_the_sweep_counts -> any;

    def test_step4_persists_the_sweeps_expiry -> any;

    def test_step5_documents_language_flag_marker -> any;

    @unittest.skipUnless(
        _HAVE_YAML,
        "PyYAML not installed (the CI Python-test job omits it; the lint job runs lint_skills.jac directly)",
    )
    def test_lint_skills_passes -> any;
}

class PostedDateStalenessSpec(unittest.TestCase) {
    def setUp -> any;

    def test_step3_consumes_posted_date -> any;

    def test_staleness_is_a_flag_never_a_veto -> any;

    def test_staleness_never_inferred_for_absent_values -> any;

    def test_staleness_parses_posted_date_defensively -> any;
}

class RankBatchLimitSpec(unittest.TestCase) {
    def setUp -> any;

    def test_step0_documents_default_limit_distinct_from_top -> any;

    def test_step1_applies_limit_via_the_state_tool -> any;

    def test_step5_reports_deferral_and_how_to_continue -> any;
}

class RankStateToolSpec(unittest.TestCase) {
    def setUp -> any;

    def _step2_result_fields -> builtins.list[builtins.str];

    def test_step1_never_reads_the_state_file_manually -> any;

    def test_step4_writes_back_through_apply_not_by_hand -> any;

    def test_step4_preserves_every_field_step2_declares -> any;

    def test_step4_documents_the_location_verdict_legacy_migration -> any;

    def test_step4_documents_deadline_null_is_not_a_correction -> any;

    def test_step3_sweep_runs_through_the_tool -> any;

    def test_tracker_stays_read_only -> any;

    def test_settings_and_guards_allow_the_new_tool -> any;
}

with entry:__main__ {
    unittest.main();
}
