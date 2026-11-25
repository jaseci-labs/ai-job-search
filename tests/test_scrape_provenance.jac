import builtins;

import unittest;

import from pathlib { Path }

glob REPO: any;

glob SKILL: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    SKILL = REPO / ".claude" / "skills" / "job-scraper" / "SKILL.md";
}

def _steps(text: builtins.str) -> builtins.dict[builtins.str, builtins.str];

class ScrapeProvenanceSpec(unittest.TestCase) {
    class def setUpClass -> any;

    def test_schema_block_carries_source_field -> any;

    def test_source_field_is_additive_and_never_backfilled -> any;

    def test_fallback_results_are_tagged_at_the_source -> any;

    def test_step5_summary_names_fallback_portals -> any;
}

class TestRecencyFallback(unittest.TestCase) {
    def test_step1b_names_a_client_side_fallback_for_flagless_portals -> any;
}

with entry:__main__ {
    unittest.main();
}
