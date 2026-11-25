"""Guards for the /upskill skill spec.

The skill is a markdown spec (the spec IS the implementation), so these
tests pin the invariants that would break silently: the header format that
lint_skills.jac enforces, and aggregate mode's merge of tracker rows with
/rank's recorded gaps from seen_jobs.json (previously aggregate mode only
read the tracker and inferred skills from free-text columns).
"""

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

"""Split a skill spec into {heading: body} by '##' headers.

    Splitting this way lets a fork's extra sections sit between the ones
    under test without shifting which text a given assertion sees.
    """
def _sections(text: builtins.str) -> builtins.dict[builtins.str, builtins.str];

class UpskillSkillSpec(unittest.TestCase) {
    def test_skill_file_exists_with_lint_compliant_header -> any;

    def test_step2_reads_ranked_jobs_with_moderate_fit_floor -> any;

    """/rank vetoes a location or language FAIL only on its shortlist:
        tools/rank_state.jac apply still stores the job as status "ranked" with
        its full score and gaps. Step 2's filter (ranked, rank_score >= 45)
        kept such a job, so a deal-breaker's gaps fed the heatmap and the
        learning plan. Drive the real write path to show the entry exists,
        then require Step 2 to drop it."""
    def test_step2_drops_jobs_rank_vetoed -> any;

    """/upskill reads the tracker, so its enumeration of the columns must
        match the header /apply writes - the deadline column (#319) is the
        first column to be added since the list was written."""
    def test_step2_column_list_keeps_in_phase_with_tracker_header -> any;

    def test_step3_documents_dedupe_and_gap_precedence -> any;

    def test_step3_dedupe_names_the_field_ranked_entries_actually_carry -> any;

    """/outcome creates tracker rows for applications made outside the
        workflow, and no rule anywhere fills fit_rating on that path - yet
        Step 3.3 divides by it. A naive read of blank as 0 yields weight 1.0
        (the maximum), making the one job the framework knows nothing about
        dominate the heatmap. The skill already handles missing gaps with
        skip+count+report; the same pattern must cover fit_rating."""
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
