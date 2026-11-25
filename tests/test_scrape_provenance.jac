import unittest;
import from pathlib { Path }

glob SKILL: str = (
         Path(__file__).resolve().parent.parent / ".claude" / "skills" / "job-scraper" / "SKILL.md"
     ).read_text(encoding="utf-8"),
     STEPS: dict[str, str] = {
         part.partition("\n")[0].strip(): part.partition("\n")[2]
         for part in SKILL.split("\n### ")[1:]
     };

class ScrapeProvenanceSpec(unittest.TestCase) {
    def test_source_field_is_stored_defined_tagged_and_reported;
}

class TestRecencyFallback(unittest.TestCase) {
    def test_step1b_names_a_client_side_fallback_for_flagless_portals;
}
