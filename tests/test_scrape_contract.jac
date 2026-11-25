"""Tests for the /scrape Step 2 search-output contract.

Mirrors the pattern of test_html_report_command.py: derive the contract from
the spec itself and compare it against the portal CLIs installed under
.agents/skills/. None ship upstream (they live in community-portals), so these
checks run on the portals a fork copies in or builds with /add-portal.

Why this test exists: .claude/skills/job-scraper/SKILL.md Step 2 promises
"Search output already includes title, company, location, date, and URL" for
every portal CLI, and Step 4.75's degraded scan flags "company null or empty
on every result" as a half-working parser. A CLI that quietly stops emitting
those fields flags the portal as degraded on every /scrape run while CI stays
green, breaks the seen_jobs.json dedupe (url_or_company_title_key), and leaves
/rank without a posting URL. That failure class landed for real: jobnet-search
emitted only the raw API schema and jobdanmark-search emitted companyName with
no company/location/date keys until both were normalized.

{helpers.ts, commands/search.ts} are the two files where every registered
CLI's search output currently lives (HTML-parsing portals normalize in
helpers.ts, API portals in commands/search.ts). detail.ts is deliberately
excluded: the contract is about the search output /scrape consumes.
"""

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

"""Every installed portal CLI's search output must carry the Step 2 contract fields."""
class ScrapeSearchOutputContractTests(unittest.TestCase) {
    """Guards the anchor the field list is derived from."""
    def test_step2_contract_sentence_is_found_in_the_scraper_skill -> any;

    def test_every_portal_cli_emits_the_step2_contract_fields -> any;
}

with entry {
    _STEP4_SCHEMA_BLOCK = re.compile("Add ALL fetched jobs.*?```json(.*?)```", re.DOTALL);
}

def derive_stored_fields -> builtins.frozenset[builtins.str];

"""The posting date Step 2 guarantees must survive into Step 4's storage.

    Step 2's contract promises a `date` on every portal CLI's search output and
    the test above keeps every CLI honest about emitting it. Step 1b then uses
    that date to scope the run to the last 14 days - and Step 4's schema drops
    it. `first_seen` records when this scraper first saw an entry, not when the
    employer posted it, so once the run ends nothing can tell a posting
    published yesterday from one published two years ago: the Step 1b window is
    unauditable and /rank has no freshness signal to weigh.

    That failure landed for real: a freehire-search posting dated 2024-05-13 was
    scraped and ranked Strong Fit at position 1 of 133, its own scoring note
    observing the listing "may be long stale" with nothing able to act on it.
    """
class SeenJobsPostingDateTests(unittest.TestCase) {
    def test_step4_schema_persists_a_posting_date -> any;

    def test_the_step2_date_field_survives_into_storage -> any;

    """A stored field the spec never explains gets backfilled by guessing."""
    def test_posted_date_semantics_are_documented -> any;
}

with entry {
    RANK_COMMAND = REPO_ROOT / ".claude" / "commands" / "rank.md";
    EMPLOYMENT_TYPES = ("full_time", "part_time", "contract", "freelance");
}

"""The engagement type a posting states must be stored and surfaced, never guessed.

    Part-time, contract and freelance postings reach the shortlist
    indistinguishable from permanent roles: Step 3 reads the posting but its
    only outputs are a fit band and highlights, so a "6-month contract" is only
    visible if the reader happens to see the title. Persisting it as a nullable
    field lets /rank show it and flag a mismatch with the user's stated
    preference, without any new profile field.
    """
class SeenJobsEmploymentTypeTests(unittest.TestCase) {
    def test_step4_schema_persists_employment_type -> any;

    def test_schema_lists_every_allowed_value_and_null -> any;

    def test_employment_type_semantics_are_documented -> any;

    static def _rank_employment_paragraph -> builtins.str;

    def test_rank_shows_it_as_a_flag_never_a_veto -> any;

    def test_rank_marks_the_type_and_its_separator_as_optional -> any;

    def test_portal_detail_output_counts_as_a_source -> any;
}

"""The new key rule must not replay jobs stored under legacy keys."""
class SeenJobsDedupContinuityTests(unittest.TestCase) {
    def test_existing_urls_are_seen_regardless_of_key -> any;

    def test_step4_presentation_mentions_url_deduplication -> any;
}

with entry {
    _QUERY_SYNTAX_LINE = re.compile("^Query syntax:\\s*\\S", re.MULTILINE);
}

"""Every installed portal SKILL.md must state its query syntax."""
class PortalQuerySyntaxTests(unittest.TestCase) {
    def test_step1b_points_at_the_query_syntax_line -> any;

    def test_every_installed_portal_skill_has_a_query_syntax_line -> any;
}

with entry:__main__ {
    unittest.main();
}
