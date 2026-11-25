import builtins;

import json;

import subprocess;

import sys;

import unittest;

import from pathlib { Path }

import from tempfile { TemporaryDirectory }

glob _HAVE_YAML: any;

glob yaml: any;

glob REPO: any;

glob SKILL: any;

glob SCRAPER: any;

glob RANK_STATE: any;

with entry {
    try {
        import yaml;
        _HAVE_YAML = True;
    } except ImportError {
        _HAVE_YAML = False;
    }

    REPO = Path(__file__).resolve().parent.parent;
    SKILL = REPO / ".claude" / "skills" / "upskill" / "SKILL.md";
    SCRAPER = REPO / ".claude" / "skills" / "job-scraper" / "SKILL.md";
    RANK_STATE = tool("rank_state");
}

def _sections(text: builtins.str) -> builtins.dict[builtins.str, builtins.str];

class UpskillSkillSpec(unittest.TestCase) {
    def test_skill_file_exists_with_lint_compliant_header -> any;

    def test_step2_reads_ranked_jobs_with_moderate_fit_floor -> any;

    def test_step2_drops_jobs_rank_vetoed -> any;

    def test_step2_column_list_keeps_in_phase_with_tracker_header -> any;

    def test_step3_documents_dedupe_and_gap_precedence -> any;

    def test_step3_dedupe_names_the_field_ranked_entries_actually_carry -> any;

    def test_step3_handles_blank_fit_rating -> any;

    def test_step5_heatmap_shows_gap_provenance -> any;

    def test_step8_report_header_counts_both_sources -> any;

    def test_important_rules_cover_untrusted_data_and_no_backfill -> any;

    @unittest.skipUnless(
        _HAVE_YAML,
        "PyYAML not installed (the CI Python-test job omits it; the lint job runs lint_skills.jac directly)",
    )
    def test_lint_skills_passes -> any;
}

with entry:__main__ {
    unittest.main();
}
