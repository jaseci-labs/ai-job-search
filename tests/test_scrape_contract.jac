import re;
import unittest;
import from pathlib { Path }

glob REPO_ROOT: Path = Path(__file__).resolve().parent.parent,
     SKILL: str = (REPO_ROOT / ".claude" / "skills" / "job-scraper" / "SKILL.md").read_text(
         encoding="utf-8"
     ),
     RANK: str = (REPO_ROOT / ".claude" / "commands" / "rank.md").read_text(encoding="utf-8"),
     PORTAL_CLIS: list[Path] = sorted((REPO_ROOT / ".agents" / "skills").glob("*-search")),
     EMPLOYMENT: str = "**Employment type:**",
     EMPLOYMENT_TYPES: tuple[str, ...] = ("full_time", "part_time", "contract", "freelance");

def contract_fields -> set[str];
def stored_fields -> set[str];
def paragraph(text: str, start: str) -> str;

class ScrapeSearchOutputContractTests(unittest.TestCase) {
    def test_step2_contract_sentence_is_found_in_the_scraper_skill;
    def test_every_portal_cli_emits_the_step2_contract_fields;
}

class SeenJobsSchemaTests(unittest.TestCase) {
    def test_step4_schema_persists_posting_date_and_employment_type;
    def test_schema_lists_every_employment_type_and_null;
    def test_storage_and_dedup_rules_are_documented;
}

class SeenJobsEmploymentTypeTests(unittest.TestCase) {
    def test_rank_shows_it_as_an_optional_flag_never_a_veto;
    def test_portal_detail_output_counts_as_a_source;
}

class PortalQuerySyntaxTests(unittest.TestCase) {
    def test_step1b_points_at_the_query_syntax_line;
    def test_every_installed_portal_skill_has_a_query_syntax_line;
}
