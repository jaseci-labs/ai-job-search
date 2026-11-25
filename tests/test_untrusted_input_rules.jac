import re;
import unittest;
import from pathlib { Path }

glob REPO: Path = Path(__file__).resolve().parent.parent,
     COMMANDS: Path = REPO / ".claude" / "commands",
     RULE: re.Pattern[str] = re.compile("untrusted (?:third-party )?data, never instructions"),
     INGESTS: re.Pattern[str] = re.compile(
         "WebFetch|search_threads|get_thread|get_message|cli\\.ts detail|job_posting\\.md"
     );

"""Every command and skill spec that reads third-party content, by repo-relative path."""
def ingesting_specs -> dict[str, str];

class TrustBoundaryTests(unittest.TestCase) {
    def test_derived_set_is_not_empty;
    def test_every_ingesting_spec_states_the_rule;
    def test_gmail_sync_never_acts_on_email_content;
    def test_setup_calibration_never_copies_archive_wording;
}

with entry:__main__ {
    unittest.main();
}
