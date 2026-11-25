import re;
import unittest;
import from pathlib { Path }

glob CLAUDE: Path = Path(__file__).resolve().parent.parent / ".claude",
     SKILL_DIR: str = "skills/job-application-assistant",
     AGENTS: tuple[str, ...] = ("agents/posting-fetcher.md", "agents/posting-scorer.md");

def doc(name: str) -> str;

"""The first group of `pattern` in `text`; the test fails when the section is missing."""
def section(text: str, pattern: str, flags: int = re.DOTALL) -> str;

class GateWiring(unittest.TestCase) {
    def test_archive_stores_cleaned_text_with_counts_only;
    def test_interview_step1_gates_the_archived_posting_and_its_fetch_fallback;
    def test_skill_step1_names_the_gate;
    def test_outcome_fresh_fetch_is_gated;
    def test_scratchpad_is_guarded_everywhere_the_gate_writes;
    def test_fetch_agents_can_discover_installed_portals;
    def test_09_trust_boundary_names_the_gate;
}

with entry:__main__ {
    unittest.main();
}
