import builtins;

import re;

import unittest;

import from pathlib { Path }

glob REPO_ROOT: any;

glob SCRAPER_SKILL: any;

glob PORTAL_CLIS: any;

glob _CONTRACT_SENTENCE: any;

glob _STEP4_SCHEMA_BLOCK: any;

glob RANK_COMMAND: any;

glob EMPLOYMENT_TYPES: any;

glob _QUERY_SYNTAX_LINE: any;

with entry {
    REPO_ROOT = Path(__file__).resolve().parent.parent;
    SCRAPER_SKILL = REPO_ROOT / ".claude" / "skills" / "job-scraper" / "SKILL.md";
    PORTAL_CLIS = sorted((REPO_ROOT / ".agents" / "skills").glob("*-search"));
    _CONTRACT_SENTENCE = re.compile(
        "Search output already includes ([a-zA-Z0-9\\s,]+)\\.", re.MULTILINE
    );
}

def derive_contract_fields -> builtins.frozenset[builtins.str];

def search_output_source(search_ts: Path) -> builtins.str;

class ScrapeSearchOutputContractTests(unittest.TestCase) {
    def test_step2_contract_sentence_is_found_in_the_scraper_skill -> any;

    def test_every_portal_cli_emits_the_step2_contract_fields -> any;
}

with entry {
    _STEP4_SCHEMA_BLOCK = re.compile("Add ALL fetched jobs.*?```json(.*?)```", re.DOTALL);
}

def derive_stored_fields -> builtins.frozenset[builtins.str];

class SeenJobsPostingDateTests(unittest.TestCase) {
    def test_step4_schema_persists_a_posting_date -> any;

    def test_the_step2_date_field_survives_into_storage -> any;

    def test_posted_date_semantics_are_documented -> any;
}

with entry {
    RANK_COMMAND = REPO_ROOT / ".claude" / "commands" / "rank.md";
    EMPLOYMENT_TYPES = ("full_time", "part_time", "contract", "freelance");
}

class SeenJobsEmploymentTypeTests(unittest.TestCase) {
    def test_step4_schema_persists_employment_type -> any;

    def test_schema_lists_every_allowed_value_and_null -> any;

    def test_employment_type_semantics_are_documented -> any;

    static def _rank_employment_paragraph -> builtins.str;

    def test_rank_shows_it_as_a_flag_never_a_veto -> any;

    def test_rank_marks_the_type_and_its_separator_as_optional -> any;

    def test_portal_detail_output_counts_as_a_source -> any;
}

class SeenJobsDedupContinuityTests(unittest.TestCase) {
    def test_existing_urls_are_seen_regardless_of_key -> any;

    def test_step4_presentation_mentions_url_deduplication -> any;
}

with entry {
    _QUERY_SYNTAX_LINE = re.compile("^Query syntax:\\s*\\S", re.MULTILINE);
}

class PortalQuerySyntaxTests(unittest.TestCase) {
    def test_step1b_points_at_the_query_syntax_line -> any;

    def test_every_installed_portal_skill_has_a_query_syntax_line -> any;
}

with entry:__main__ {
    unittest.main();
}
