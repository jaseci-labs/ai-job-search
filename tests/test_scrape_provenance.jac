"""Guards for /scrape's result-provenance recording.

The scraper is a markdown spec (the spec IS the implementation), so these
tests pin the invariants that would break silently: seen_jobs.json entries
record whether they came from a portal CLI or the WebSearch fallback
(`source`), and the Step 5 summary names the portals that ran on the
fallback. Together these keep a ghost-job report diagnosable days after
the run's scrollback is gone (#331): a stale-index entry, a live-CLI
entry, and a job with no entry at all each point at a different mechanism.
"""

import builtins;

import unittest;

import from pathlib { Path }

glob REPO: any;

glob SKILL: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    SKILL = REPO / ".claude" / "skills" / "job-scraper" / "SKILL.md";
}

"""Split the skill spec into {heading: body} by '###' step headers.

    Splitting this way lets a fork's extra steps sit between the ones
    under test without shifting which text a given assertion sees.
    """
def _steps(text: builtins.str) -> builtins.dict[builtins.str, builtins.str];

class ScrapeProvenanceSpec(unittest.TestCase) {
    class def setUpClass -> any;

    def test_schema_block_carries_source_field -> any;

    def test_source_field_is_additive_and_never_backfilled -> any;

    def test_fallback_results_are_tagged_at_the_source -> any;

    def test_step5_summary_names_fallback_portals -> any;
}

"""Step 1b.3 says to scope to the last 14 days via the portal's recency
    flag - but not every portal has one (jobdanmark offers no date filter or
    sort at all), which left the instruction unsatisfiable there: the agent
    either silently skipped the scoping or invented a flag, and inventing a
    flag is exactly what the UNKNOWN_FLAG rejection now errors on (review
    finding F32, 2026-08-19). Every portal emits a `date` field, so
    client-side filtering is always available as the fallback."""
class TestRecencyFallback(unittest.TestCase) {
    def test_step1b_names_a_client_side_fallback_for_flagless_portals -> any;
}

with entry:__main__ {
    unittest.main();
}
